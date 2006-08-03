/*
  sysvipc.c - SystemV IPC support for Ruby

  Copyright (C) 2001  Daiki Ueno

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <sys/sem.h>
#include <sys/shm.h>
#include <errno.h>
#include "ruby.h"
#include "rubysig.h"

#ifndef EWOULDBLOCK
#define EWOULDBLOCK EAGAIN
#endif

struct ipcid_ds {
  int id;
  int flags;
  union {
    struct msqid_ds msgstat;
    struct semid_ds semstat;
    struct shmid_ds shmstat;
  } u;

#define msgstat u.msgstat
#define semstat u.semstat
#define shmstat u.shmstat

  void (*stat) (struct ipcid_ds *);
  void (*rmid) (struct ipcid_ds *);
  struct ipc_perm * (*perm) (struct ipcid_ds *);

  void *data;
};

struct msgbuf {
  long mtype;
  char mtext[1];
};

#if (defined(__GNU_LIBRARY__) && !defined(_SEM_SEMUN_UNDEFINED)) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__bsdi__)
/* union semun is defined by including <sys/sem.h> */
#else
/* according to X/OPEN we have to define it ourselves */
union semun {
  int val;                    /* value for SETVAL */
  struct semid_ds *buf;       /* buffer for IPC_STAT, IPC_SET */
  unsigned short int *array;  /* array for GETALL, SETALL */
  struct seminfo *__buf;      /* buffer for IPC_INFO */
};
#endif

static VALUE cError;

static VALUE
rb_ftok (klass, v_path, v_id)
     VALUE klass, v_path, v_id;
{
  const char *path = STR2CSTR (v_path);
  key_t key;

  key = ftok (path, NUM2INT (v_id) & 0x7f);
  if (key == -1)
    rb_sys_fail ("ftok(2)");

  return INT2FIX (key);
}

static struct ipcid_ds *
get_ipcid (obj)
     VALUE obj;
{
  struct ipcid_ds *ipcid;
  Data_Get_Struct (obj, struct ipcid_ds, ipcid);

  if (ipcid->id < 0)
    rb_raise (cError, "closed handle");
  return ipcid;
}

static struct ipcid_ds *
get_ipcid_and_stat (obj)
     VALUE obj;
{
  struct ipcid_ds *ipcid;
  ipcid = get_ipcid (obj);
  ipcid->stat (ipcid);
  return ipcid;
}

static VALUE
rb_ipc_remove (obj)
     VALUE obj;
{
  struct ipcid_ds *ipcid;

  ipcid = get_ipcid (obj);
  ipcid->rmid (ipcid);

  return obj;
}

static void
msg_stat (msgid)
     struct ipcid_ds *msgid;
{
  if (msgctl (msgid->id, IPC_STAT, &msgid->msgstat) == -1)
    rb_sys_fail ("msgctl(2)");
}

static struct ipc_perm *
msg_perm (msgid)
     struct ipcid_ds *msgid;
{
  return &msgid->msgstat.msg_perm;
}

static void
msg_rmid (msgid)
     struct ipcid_ds *msgid;
{
  if (msgid->id < 0)
    rb_raise (cError, "already removed");
  if (msgctl (msgid->id, IPC_RMID, 0) == -1)
    rb_sys_fail ("msgctl(2)");
  msgid->id = -1;
}

static VALUE
rb_msg_s_new (argc, argv, klass)
     int argc;
     VALUE *argv, klass;
{
  struct ipcid_ds *msgid;
  VALUE dst, v_key, v_msgflg;

  dst = Data_Make_Struct (klass, struct ipcid_ds, NULL, free, msgid);
  rb_scan_args (argc, argv, "11", &v_key, &v_msgflg);
  if (!NIL_P (v_msgflg))
    msgid->flags = NUM2INT (v_msgflg);
  msgid->id = msgget ((key_t)NUM2INT (v_key), msgid->flags);
  if (msgid->id == -1)
    rb_sys_fail ("msgget(2)");
  msgid->stat = msg_stat;
  msgid->perm = msg_perm;
  msgid->rmid = msg_rmid;

  return dst;
}

static VALUE
rb_msg_send (argc, argv, obj)
     int argc;
     VALUE *argv, obj;
{
  VALUE v_type, v_buf, v_flags;
  int flags = 0, error;
  struct msgbuf *msgp;
  struct ipcid_ds *msgid;
  char *buf;
  size_t len;

  rb_scan_args (argc, argv, "21", &v_type, &v_buf, &v_flags);
  if (!NIL_P (v_flags))
    flags = NUM2INT (v_flags);
  
  len = RSTRING (v_buf)->len;
  buf = RSTRING (v_buf)->ptr;

  msgp = xcalloc (sizeof (long) + len, sizeof (char));
  msgp->mtype = NUM2LONG (v_type);
  memcpy (msgp->mtext, buf, len);

  msgid = get_ipcid (obj);
 retry:
  TRAP_BEG;
  error = msgsnd (msgid->id, msgp, len, flags);
  TRAP_END;
  if (error == -1)
    {
      switch (errno)
	{
	case EINTR:
	  rb_thread_schedule ();
	case EWOULDBLOCK:
#if EAGAIN != EWOULDBLOCK
	case EAGAIN:
#endif
	  goto retry;
	}
      rb_sys_fail ("msgsnd(2)");
    }

  return obj;
}

static VALUE
rb_msg_recv (argc, argv, obj)
     int argc;
     VALUE *argv, obj;
{
  VALUE v_type, v_len, v_flags;
  int flags = 0;
  struct msgbuf *msgp;
  struct ipcid_ds *msgid;
  long type;
  size_t rlen, len;

  rb_scan_args (argc, argv, "21", &v_type, &v_len, &v_flags);
  type = NUM2LONG (v_type);
  len = NUM2INT (v_len);
  if (!NIL_P (v_flags))
    flags = NUM2INT (v_flags);

  msgp = xcalloc (sizeof (long) + len, sizeof (char));
  msgid = get_ipcid (obj);

 retry:
  TRAP_BEG;
  rlen = msgrcv (msgid->id, msgp, len, type, flags);
  TRAP_END;
  if (rlen == (size_t)-1)
    {
      switch (errno)
	{
	case EINTR:
	  rb_thread_schedule ();
	case EWOULDBLOCK:
#if EAGAIN != EWOULDBLOCK
	case EAGAIN:
#endif
	  goto retry;
	}
      rb_sys_fail ("msgrcv(2)");
    }

  return rb_str_new (msgp->mtext, rlen);
}

static void
sem_stat (semid)
     struct ipcid_ds *semid;
{
  if (semctl (semid->id, 0, IPC_STAT, (union semun)&semid->semstat) == -1)
    rb_sys_fail ("semctl(2)");
}

static struct ipc_perm *
sem_perm (semid)
     struct ipcid_ds *semid;
{
  return &semid->semstat.sem_perm;
}

static void
sem_rmid (semid)
     struct ipcid_ds *semid;
{
  if (semid->id < 0)
    rb_raise (cError, "already removed");
  if (semctl (semid->id, 0, IPC_RMID, 0) == -1)
    rb_sys_fail ("semctl(2)");
  semid->id = -1;
}

static VALUE
rb_sem_s_new (argc, argv, klass)
     int argc;
     VALUE *argv, klass;
{
  struct ipcid_ds *semid;
  VALUE dst, v_key, v_nsems, v_semflg;
  int nsems;

  dst = Data_Make_Struct (klass, struct ipcid_ds, NULL, free, semid);
  rb_scan_args (argc, argv, "12", &v_key, &v_nsems, &v_semflg);
  if (!NIL_P (v_nsems))
    nsems = NUM2INT (v_nsems);
  if (!NIL_P (v_semflg))
    semid->flags = NUM2INT (v_semflg);
  semid->id = semget ((key_t)NUM2INT (v_key), nsems, semid->flags);
  if (semid->id == -1)
    rb_sys_fail ("semget(2)");
  semid->stat = sem_stat;
  semid->perm = sem_perm;
  semid->rmid = sem_rmid;

  return dst;
}

#define Check_Valid_Semnum(n, semid)		\
  if (n > semid->semstat.sem_nsems)		\
    rb_raise (cError, "invalid semnum")

static VALUE
rb_sem_to_a (obj)
     VALUE obj;
{
  struct ipcid_ds *semid;
  unsigned short int *array;
  int i, nsems;
  VALUE dst;

  semid = get_ipcid_and_stat (obj);
  nsems = semid->semstat.sem_nsems;
  array = xcalloc (nsems, sizeof (unsigned short int));

  semctl (semid->id, 0, GETALL, array);

  dst = rb_ary_new ();
  for (i = 0; i < nsems; i++)
    rb_ary_push (dst, INT2FIX (array[i]));

  return dst;
}

static VALUE
rb_sem_set_all (obj, ary)
     VALUE obj, ary;
{
  struct ipcid_ds *semid;
  unsigned short int *array;
  int i, nsems;

  semid = get_ipcid_and_stat (obj);
  nsems = semid->semstat.sem_nsems;

  if (RARRAY(ary)->len != nsems)
    rb_raise (cError, "doesn't match with semnum");

  array = xcalloc (nsems, sizeof (unsigned short int));
  for (i = 0; i < nsems; i++)
    array[i] = NUM2INT (RARRAY(ary)->ptr[i]);
  semctl (semid->id, 0, SETALL, array);

  return obj;
}

static VALUE
rb_sem_value (obj, n)
     VALUE obj, n;
{
  struct ipcid_ds *semid;
  int value;

  semid = get_ipcid_and_stat (obj);
  Check_Valid_Semnum (n, semid);
  value = semctl (semid->id, NUM2INT (n), GETVAL, 0);
  if (value == -1)
    rb_sys_fail ("semctl(2)");
  return INT2FIX (value);
}

static VALUE
rb_sem_set_value (obj, v_pos, v_value)
     VALUE obj, v_pos, v_value;
{
  struct ipcid_ds *semid;
  int pos;

  semid = get_ipcid_and_stat (obj);
  pos = NUM2INT (v_pos);
  Check_Valid_Semnum (pos, semid);
  if (semctl (semid->id, pos, SETVAL, NUM2INT (v_value)) == -1)
    rb_sys_fail ("semctl(2)");
  return obj;
}

static VALUE
rb_sem_ncnt (obj, v_pos)
     VALUE obj, v_pos;
{
  struct ipcid_ds *semid;
  int ncnt, pos;

  semid = get_ipcid_and_stat (obj);
  pos = NUM2INT (v_pos);
  Check_Valid_Semnum (pos, semid);
  ncnt = semctl (semid->id, pos, GETNCNT, 0);
  if (ncnt == -1)
    rb_sys_fail ("semctl(2)");
  return INT2FIX (ncnt);
}

static VALUE
rb_sem_zcnt (obj, v_pos)
     VALUE obj, v_pos;
{
  struct ipcid_ds *semid;
  int zcnt, pos;

  semid = get_ipcid_and_stat (obj);
  pos = NUM2INT (v_pos);
  Check_Valid_Semnum (pos, semid);
  zcnt = semctl (semid->id, pos, GETZCNT, 0);
  if (zcnt == -1)
    rb_sys_fail ("semctl(2)");
  return INT2FIX (zcnt);
}

static VALUE
rb_sem_pid (obj, v_pos)
     VALUE obj, v_pos;
{
  struct ipcid_ds *semid;
  int pid, pos;

  semid = get_ipcid_and_stat (obj);
  pos = NUM2INT (v_pos);
  Check_Valid_Semnum (pos, semid);
  pid = semctl (semid->id, pos, GETPID, 0);
  if (pid == -1)
    rb_sys_fail ("semctl(2)");
  return INT2FIX (pid);
}

static VALUE
rb_sem_size (obj)
     VALUE obj;
{
  struct ipcid_ds *semid;
  semid = get_ipcid_and_stat (obj);
  return INT2FIX (semid->semstat.sem_nsems);
}

static VALUE
rb_sem_apply (obj, ary)
     VALUE obj, ary;
{
  struct ipcid_ds *semid;
  struct sembuf *array;
  int nsops, i, nsems;

  semid = get_ipcid_and_stat (obj);
  nsems = semid->semstat.sem_nsems;
  nsops = RARRAY(ary)->len;
  array = xcalloc (nsems, sizeof (struct sembuf));
  for (i = 0; i < nsops; i++)
    {
      struct sembuf *op;
      Data_Get_Struct (RARRAY(ary)->ptr[i], struct sembuf, op);
      memcpy (&array[i], op, sizeof (struct sembuf));
      Check_Valid_Semnum (array[i].sem_num, semid);
    }
      
  if (semop (semid->id, array, nsops) == -1)
    rb_sys_fail ("semop(2)");
  return obj;
}

static void
shm_stat (shmid)
     struct ipcid_ds *shmid;
{
  if (shmctl (shmid->id, IPC_STAT, &shmid->shmstat) == -1)
    rb_sys_fail ("shmctl(2)");
}

static struct ipc_perm *
shm_perm (shmid)
     struct ipcid_ds *shmid;
{
  return &shmid->shmstat.shm_perm;
}

static void
shm_rmid (shmid)
     struct ipcid_ds *shmid;
{
  if (shmid->id < 0)
    rb_raise (cError, "already removed");
  if (shmctl (shmid->id, IPC_RMID, 0) == -1)
    rb_sys_fail ("shmctl(2)");
  shmid->id = -1;
}

static VALUE
rb_shm_s_new (argc, argv, klass)
     int argc;
     VALUE *argv, klass;
{
  struct ipcid_ds *shmid;
  VALUE dst, v_key, v_size, v_shmflg;
  int size;

  dst = Data_Make_Struct (klass, struct ipcid_ds, NULL, free, shmid);
  rb_scan_args (argc, argv, "12", &v_key, &v_size, &v_shmflg);
  if (!NIL_P (v_size))
    size = NUM2INT (v_size);
  if (!NIL_P (v_shmflg))
    shmid->flags = NUM2INT (v_shmflg);
  shmid->id = shmget ((key_t)NUM2INT (v_key), size, shmid->flags);
  if (shmid->id == -1)
    rb_sys_fail ("shmget(2)");
  shmid->stat = shm_stat;
  shmid->perm = shm_perm;
  shmid->rmid = shm_rmid;

  return dst;
}

static VALUE
rb_shm_attach (argc, argv, obj)
     int argc;
     VALUE *argv, obj;
{
  VALUE v_flags;
  struct ipcid_ds *shmid;
  int flags = 0;
  void *data;

  shmid = get_ipcid (obj);
  if (shmid->data)
    rb_raise (cError, "already attached");

  rb_scan_args (argc, argv, "01", &v_flags);
  if (!NIL_P (v_flags))
    flags = NUM2INT (v_flags);

  data = shmat (shmid->id, 0, flags);
  if (data == (void*)-1)
    rb_sys_fail ("shmat(2)");
  shmid->data = data;

  return obj;
}

static VALUE
rb_shm_detach (obj)
     VALUE obj;
{
  struct ipcid_ds *shmid;

  shmid = get_ipcid (obj);
  if (!shmid->data)
    rb_raise (cError, "already detached");

  if (shmdt (shmid->data) == -1)
    rb_sys_fail ("shmdt(2)");
  shmid->data = NULL;

  return obj;
}

#define Check_Valid_Shm_Segsz(n, shmid)		\
  if (n > shmid->shmstat.shm_segsz)		\
    rb_raise (cError, "invalid shm_segsz")

static VALUE
rb_shm_read (argc, argv, obj)
     int argc;
     VALUE *argv, obj;
{
  struct ipcid_ds *shmid;
  VALUE v_len;
  int len;

  shmid = get_ipcid (obj);
  if (!shmid->data)
    rb_raise (cError, "detached memory");
  shmid->stat (shmid);

  len = shmid->shmstat.shm_segsz;
  rb_scan_args (argc, argv, "01", &v_len);
  if (!NIL_P (v_len))
    len = NUM2INT (v_len);
  Check_Valid_Shm_Segsz (len, shmid);

  return rb_str_new (shmid->data, len);
}

static VALUE
rb_shm_write (obj, v_buf)
     VALUE obj, v_buf;
{
  struct ipcid_ds *shmid;
  int i, len;
  char *buf;

  shmid = get_ipcid (obj);
  if (!shmid->data)
    rb_raise (cError, "detached memory");
  shmid->stat (shmid);

  len = RSTRING (v_buf)->len;
  Check_Valid_Shm_Segsz (len, shmid);

  buf = shmid->data;
  for (i = 0; i < len; i++)
    *buf++ = RSTRING (v_buf)->ptr[i];

  return obj;
}

static VALUE
rb_shm_size (obj)
     VALUE obj;
{
  struct ipcid_ds *shmid;
  shmid = get_ipcid_and_stat (obj);
  return INT2FIX (shmid->shmstat.shm_segsz);
}

static VALUE
rb_semop_s_new (argc, argv, klass)
     int argc;
     VALUE *argv, klass;
{
  struct sembuf *op;
  VALUE dst, v_pos, v_value, v_flags;

  dst = Data_Make_Struct (klass, struct sembuf, NULL, free, op);
  rb_scan_args (argc, argv, "21", &v_pos, &v_value, &v_flags);
  op->sem_num = NUM2INT (v_pos);
  op->sem_op = NUM2INT (v_value);
  if (!NIL_P (v_flags))
    op->sem_flg = NUM2INT (v_flags);

  return dst;
}

static VALUE
rb_semop_pos (obj)
     VALUE obj;
{
  struct sembuf *op;

  Data_Get_Struct (obj, struct sembuf, op);
  return INT2FIX (op->sem_num);
}

static VALUE
rb_semop_value (obj)
     VALUE obj;
{
  struct sembuf *op;

  Data_Get_Struct (obj, struct sembuf, op);
  return INT2FIX (op->sem_op);
}

static VALUE
rb_semop_flags (obj)
     VALUE obj;
{
  struct sembuf *op;

  Data_Get_Struct (obj, struct sembuf, op);
  return INT2FIX (op->sem_flg);
}

static VALUE
rb_perm_s_new (klass, v_ipcid)
     VALUE klass, v_ipcid;
{
  struct ipcid_ds *ipcid;
  struct ipc_perm *perm;

  Data_Get_Struct (v_ipcid, struct ipcid_ds, ipcid);
  ipcid->stat (ipcid);

  perm = xmalloc (sizeof (struct ipc_perm));
  memcpy (perm, ipcid->perm (ipcid), sizeof (struct ipc_perm));
  
  return Data_Wrap_Struct (klass, NULL, free, perm);
}

static VALUE
rb_perm_cuid (obj)
     VALUE obj;
{
  struct ipc_perm *perm;

  Data_Get_Struct (obj, struct ipc_perm, perm);
  return INT2FIX (perm->cuid);
}

static VALUE
rb_perm_cgid (obj)
     VALUE obj;
{
  struct ipc_perm *perm;

  Data_Get_Struct (obj, struct ipc_perm, perm);
  return INT2FIX (perm->cgid);
}

static VALUE
rb_perm_uid (obj)
     VALUE obj;
{
  struct ipc_perm *perm;

  Data_Get_Struct (obj, struct ipc_perm, perm);
  return INT2FIX (perm->uid);
}

static VALUE
rb_perm_gid (obj)
     VALUE obj;
{
  struct ipc_perm *perm;

  Data_Get_Struct (obj, struct ipc_perm, perm);
  return INT2FIX (perm->gid);
}

static VALUE
rb_perm_mode (obj)
     VALUE obj;
{
  struct ipc_perm *perm;

  Data_Get_Struct (obj, struct ipc_perm, perm);
  return INT2FIX (perm->mode);
}

void Init_sysvipc ()
{
  VALUE mSystemVIPC, cPermission, cIPCObject, cSemaphoreOparation;
  VALUE cMessageQueue, cSemaphore, cSharedMemory;

  mSystemVIPC = rb_define_module ("SystemVIPC");
  rb_define_module_function (mSystemVIPC, "ftok", rb_ftok, 2);

  cPermission =
    rb_define_class_under (mSystemVIPC, "Permission", rb_cObject);
  rb_define_singleton_method (cPermission, "new", rb_perm_s_new, 1);
  rb_define_method (cPermission, "cuid", rb_perm_cuid, 0);
  rb_define_method (cPermission, "cgid", rb_perm_cgid, 0);
  rb_define_method (cPermission, "uid", rb_perm_uid, 0);
  rb_define_method (cPermission, "gid", rb_perm_gid, 0);
  rb_define_method (cPermission, "mode", rb_perm_mode, 0);

  cIPCObject =
    rb_define_class_under (mSystemVIPC, "IPCObject", rb_cObject);
  rb_define_method (cIPCObject, "remove", rb_ipc_remove, 0);
  rb_undef_method (CLASS_OF (cIPCObject), "new");

  cSemaphoreOparation =
    rb_define_class_under (mSystemVIPC, "SemaphoreOperation", rb_cObject);
  rb_define_singleton_method (cSemaphoreOparation, "new", rb_semop_s_new, -1);
  rb_define_method (cSemaphoreOparation, "pos", rb_semop_pos, 0);
  rb_define_method (cSemaphoreOparation, "value", rb_semop_value, 0);
  rb_define_method (cSemaphoreOparation, "flags", rb_semop_flags, 0);

  cError =
    rb_define_class_under (mSystemVIPC, "Error", rb_eStandardError);
  cMessageQueue =
    rb_define_class_under (mSystemVIPC, "MessageQueue", cIPCObject);
  rb_define_singleton_method (cMessageQueue, "new", rb_msg_s_new, -1);
  rb_define_method (cMessageQueue, "send", rb_msg_send, -1);
  rb_define_method (cMessageQueue, "recv", rb_msg_recv, -1);

  cSemaphore =
    rb_define_class_under (mSystemVIPC, "Semaphore", cIPCObject);
  rb_define_singleton_method (cSemaphore, "new", rb_sem_s_new, -1);
  rb_define_method (cSemaphore, "to_a", rb_sem_to_a, 0);
  rb_define_method (cSemaphore, "set_all", rb_sem_set_all, 1);
  rb_define_method (cSemaphore, "value", rb_sem_value, 1);
  rb_define_method (cSemaphore, "set_value", rb_sem_set_value, 2);
  rb_define_method (cSemaphore, "n_count", rb_sem_ncnt, 1);
  rb_define_method (cSemaphore, "z_count", rb_sem_zcnt, 1);
  rb_define_method (cSemaphore, "pid", rb_sem_pid, 1);
  rb_define_method (cSemaphore, "apply", rb_sem_apply, 1);
  rb_define_method (cSemaphore, "size", rb_sem_size, 1);

  cSharedMemory =
    rb_define_class_under (mSystemVIPC, "SharedMemory", cIPCObject);
  rb_define_singleton_method (cSharedMemory, "new", rb_shm_s_new, -1);
  rb_define_method (cSharedMemory, "attach", rb_shm_attach, -1);
  rb_define_method (cSharedMemory, "detach", rb_shm_detach, 0);
  rb_define_method (cSharedMemory, "read", rb_shm_read, -1);
  rb_define_method (cSharedMemory, "write", rb_shm_write, 1);
  rb_define_method (cSharedMemory, "size", rb_shm_size, 0);

  rb_define_const (mSystemVIPC, "IPC_PRIVATE", INT2FIX (IPC_PRIVATE));
  rb_define_const (mSystemVIPC, "IPC_CREAT", INT2FIX (IPC_CREAT));
  rb_define_const (mSystemVIPC, "IPC_EXCL", INT2FIX (IPC_EXCL));
  rb_define_const (mSystemVIPC, "IPC_NOWAIT", INT2FIX (IPC_NOWAIT));
  rb_define_const (mSystemVIPC, "SEM_UNDO", INT2FIX (SEM_UNDO));
}
