/*
 * SysVIPC: System V IPC support for Ruby
 * 
 * $Source$
 *
 * $Revision$
 * $Date$
 *
 * Copyright (C) 2001, 2006, 2007  Daiki Ueno
 * Copyright (C) 2006, 2007  James Steven Jenkins
 * 
 * SysVIPC is copyrighted free software by Daiki Ueno, Steven Jenkins,
 * and others.  You can redistribute it and/or modify it under either
 * the terms of the GNU General Public License Version 2 (see file 'GPL'),
 * or the conditions below:
 * 
 *   1. You may make and give away verbatim copies of the source form of the
 *      software without restriction, provided that you duplicate all of the
 *      original copyright notices and associated disclaimers.
 * 
 *   2. You may modify your copy of the software in any way, provided that
 *      you do at least ONE of the following:
 * 
 *        a) place your modifications in the Public Domain or otherwise
 *           make them Freely Available, such as by posting said
 * 	  modifications to Usenet or an equivalent medium, or by allowing
 * 	  the author to include your modifications in the software.
 * 
 *        b) use the modified software only within your corporation or
 *           organization.
 * 
 *        c) rename any non-standard executables so the names do not conflict
 * 	  with standard executables, which must also be provided.
 * 
 *        d) make other distribution arrangements with the author.
 * 
 *   3. You may distribute the software in object code or executable
 *      form, provided that you do at least ONE of the following:
 * 
 *        a) distribute the executables and library files of the software,
 * 	  together with instructions (in the manual page or equivalent)
 * 	  on where to get the original distribution.
 * 
 *        b) accompany the distribution with the machine-readable source of
 * 	  the software.
 * 
 *        c) give non-standard executables non-standard names, with
 *           instructions on where to get the original software distribution.
 * 
 *        d) make other distribution arrangements with the author.
 * 
 *   4. You may modify and include the part of the software into any other
 *      software (possibly commercial).  
 * 
 *   5. The scripts and library files supplied as input to or produced as 
 *      output from the software do not automatically fall under the
 *      copyright of the software, but belong to whomever generated them, 
 *      and may be sold commercially, and may be aggregated with this
 *      software.
 * 
 *   6. THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
 *      IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 *      WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *      PURPOSE.
 */

%module SysVIPC

%constant char RELEASE[] = "0.9.1-rc1";

/*
 * Headers and declarations required by generated C wrapper code.
 */

%{
#include <rubysig.h>

#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <sys/sem.h>
#include <sys/shm.h>

#ifndef EWOULDBLOCK
#define EWOULDBLOCK EAGAIN
#endif

#ifndef HAVE_TYPE_STRUCT_MSGBUF
struct msgbuf {
    long mtype;
    char mtext[1];
};
#endif

struct Msgbuf {
    long int        mtype;
    VALUE          mtext;
};

#ifndef HAVE_TYPE_UNION_SEMUN
union semun {
    int              val;
    struct semid_ds *buf;
    unsigned short  *array;
};
#endif

struct Semun {
    int              val;
    struct semid_ds *buf;
    VALUE            array;
};

struct shmaddr {
    void *p;
};

%}

/*
 * SWIG Interface Definitions
 *
 * Based on Single Unix Specification, Version 2.
 */

%include typemaps.i

/* globals */

extern const int errno;

/*
 * sys/types.h
 */

/* typedefs */

/*
 * SWIG doesn't care how big the following are, just that they are
 * arithmetic types. 
 */

typedef unsigned gid_t;
typedef unsigned key_t;
typedef unsigned mode_t;
typedef int      pid_t;
typedef unsigned size_t;
typedef int      ssize_t;
typedef unsigned time_t;
typedef unsigned uid_t;

/*
 * sys/ipc.h
 */

/* constants */

%constant int IPC_CREAT = IPC_CREAT;
%constant int IPC_EXCL = IPC_EXCL;
%constant int IPC_NOWAIT = IPC_NOWAIT;

%constant int IPC_PRIVATE = IPC_PRIVATE;

%constant int IPC_RMID = IPC_RMID;
%constant int IPC_SET = IPC_SET;
%constant int IPC_STAT = IPC_STAT;

/* structs */

struct ipc_perm {
    uid_t    uid;
    gid_t    gid;
    uid_t    cuid;
    gid_t    cgid;
    mode_t   mode;
};

/* functions */

key_t  ftok(const char *, int);

/*
 * sys/msg.h
 */

/* typedefs */

typedef unsigned int msgqnum_t;
typedef unsigned int msglen_t;

/* constants */

%constant int MSG_NOERROR = MSG_NOERROR;

/* structs */

struct msqid_ds {
    struct ipc_perm msg_perm;
    msgqnum_t       msg_qnum;
    msglen_t        msg_qbytes;
    pid_t           msg_lspid;
    pid_t           msg_lrpid;
    time_t          msg_stime;
    time_t          msg_rtime;
    time_t          msg_ctime;
};

struct Msgbuf {
    long int        mtype;
    VALUE          mtext;
};

/* functions */

int       msgctl(int, int, struct msqid_ds *);
int       msgget(key_t, int);

%rename(msgrcv) inner_msgrcv;
%inline %{
static VALUE
inner_msgrcv(int msqid, struct Msgbuf *msgp, size_t msgsz,
    long msgtyp, int msgflg)
{
    int len, nowait = 0, ret;
    struct msgbuf *bufp;

    len = sizeof (long) + msgsz;
    bufp = (struct msgbuf *) ALLOCA_N(char, len);

    nowait = msgflg & IPC_NOWAIT;
    if (!rb_thread_alone()) msgflg |= IPC_NOWAIT;

    retry:
    TRAP_BEG;
    ret = msgrcv(msqid, bufp, msgsz, msgtyp, msgflg);
    TRAP_END;
    if (ret == -1) {
        switch (errno) {
        case EINTR:
            goto retry;
        case ENOMSG:
        case EWOULDBLOCK:
#if EAGAIN != EWOULDBLOCK
        case EAGAIN:
#endif
            if (!nowait) {
                rb_thread_polling ();
                goto retry;
            }
        }
    } else {
        msgp->mtype = bufp->mtype;
        msgp->mtext = rb_str_new(bufp->mtext, ret);
    }
    return LONG2NUM(ret);
}
%}

%rename(msgsnd) inner_msgsnd;
%inline %{
static VALUE
inner_msgsnd(int msqid, const struct Msgbuf *msgp, size_t msgsz, int msgflg)
{
    int len, slen, nowait = 0, ret;
    struct msgbuf *bufp;
    VALUE s;

    len = sizeof (long) + msgsz;
    bufp = (struct msgbuf *) ALLOCA_N(char, len);

    bufp->mtype = msgp->mtype;
    s = rb_check_string_type(msgp->mtext);
    slen = RSTRING_LEN(s);
    if (slen < msgsz) msgsz = slen;
    memcpy(bufp->mtext, RSTRING_PTR(s), msgsz);

    nowait = msgflg & IPC_NOWAIT;
    if (!rb_thread_alone()) msgflg |= IPC_NOWAIT;

    retry:
    TRAP_BEG;
    ret = msgsnd(msqid, bufp, msgsz, msgflg);
    TRAP_END;
    if (ret == -1) {
        switch (errno) {
        case EINTR:
            goto retry;
        case EWOULDBLOCK:
#if EAGAIN != EWOULDBLOCK
        case EAGAIN:
#endif
            if (!nowait) {
                rb_thread_polling ();
                goto retry;
            }
        }
    }
    return INT2FIX(ret);
}
%}

/*
 * sys/sem.h
 */

/* constants */

%constant int SEM_UNDO = SEM_UNDO;

%constant int GETNCNT = GETNCNT;
%constant int GETPID = GETPID;
%constant int GETVAL = GETVAL;
%constant int GETALL = GETALL;
%constant int GETZCNT = GETZCNT;
%constant int SETVAL = SETVAL;
%constant int SETALL = SETALL;

/* structs */

struct semid_ds {
    struct ipc_perm    sem_perm;
    unsigned short int sem_nsems;
    time_t             sem_otime;
    time_t             sem_ctime;
};

struct sembuf {
    unsigned short int sem_num;
    short int          sem_op;
    short int          sem_flg;
};

struct Semun {
    int              val;
    struct semid_ds *buf;
    VALUE  array;
};

/*
 * Typemap to allow semctl() to take an optional final argument.
 */

%typemap(default) struct Semun * {
}

/* functions */

/*
 * Shim semctl() to build union semun on the fly.
 */

%rename(semctl) inner_semctl;
%inline %{
static VALUE inner_semctl(int semid, int semnum, int cmd, struct Semun *arg)
{
    int i, len, nsems, ret;
    unsigned short *ap;
    union semun us, tus;
    VALUE array;
    struct semid_ds semid_ds;

    switch (cmd) {
    case SETVAL:
        us.val = arg->val;
        break;
    case GETALL:
    case SETALL:

        /* allocate us.array */

        tus.buf = &semid_ds;
        ret = semctl(semid, 0, IPC_STAT, tus);
        if (ret == -1) return INT2FIX(ret);
        len = tus.buf->sem_nsems;
        us.array = ap = ALLOCA_N(unsigned short, len);

        switch (cmd) {
        case SETALL:
            array = arg->array;
            array = rb_check_array_type(array);
            if (RARRAY(array)->len < len) len = RARRAY(array)->len;
            for (i = 0; i < len; i++) {
                *(ap++) = NUM2INT(rb_ary_entry(array, i));
            }
            break;
        }
        break;
    case IPC_STAT:
    case IPC_SET:
        us.buf = arg->buf;
        break;
    }
    ret = semctl(semid, semnum, cmd, us);
    switch (cmd) {
    case GETALL:
        arg->array = rb_ary_new2(len);
        for (i = 0, ap = us.array; i < len; i++) {
            rb_ary_store(arg->array, i, INT2NUM(*ap++));
        }
        break;
    }
    return INT2FIX(ret);
}
%}

int   semget(key_t, int, int);

/*
 * Typemap to convert Ruby array into array of struct sembuf
 * for semop().
 */

%typemap(in) struct sembuf [ANY] {
  struct sembuf *sp, *t;
  int i, len;

  Check_Type($input, T_ARRAY);
  len = RARRAY($input)->len;
  $1 = sp = (struct sembuf *) ALLOCA_N(struct sembuf, len);
  for (i = 0; i < len; i++) {
    Data_Get_Struct(rb_ary_entry($input, i), struct sembuf, t);
    memcpy(sp++, t, sizeof(struct sembuf));
  }
}

/*
 * Shim semop() to make it thread-safe.
 */

%rename(semop) inner_semop;
%inline %{
static VALUE inner_semop(int semid, struct sembuf sops[], size_t nsops)
{
    int i, ret, nowait = 0;

    for (i = 0; i < nsops; i++) {
      nowait = nowait || (sops[i].sem_flg & IPC_NOWAIT);
      if (!rb_thread_alone()) sops[i].sem_flg |= IPC_NOWAIT;
    }
    retry:
    TRAP_BEG;
    ret = INT2FIX(semop(semid, sops, nsops));
    TRAP_END;
    if (ret == -1) {
      switch (errno) {
        case EINTR:
            goto retry;
        case EWOULDBLOCK:
#if EAGAIN != EWOULDBLOCK
        case EAGAIN:
#endif
          if (!nowait) {
              rb_thread_polling ();
              goto retry;
            }
        }
    }
    return ret;
}
%}

/*
 * sys/shm.h
 */

/* typedefs */

typedef unsigned shmatt_t;

/* constants */

%constant int SHM_RDONLY = SHM_RDONLY;
%constant int SHMLBA = SHMLBA;
%constant int SHM_RND = SHM_RND;

/* structs */

struct shmid_ds {
    struct ipc_perm shm_perm;
    size_t          shm_segsz;
    pid_t           shm_lpid;
    pid_t           shm_cpid;
    shmatt_t        shm_nattch;
    time_t          shm_atime;
    time_t          shm_dtime;
    time_t          shm_ctime;
};

struct shmaddr {
};

/* functions */

struct shmaddr *shmat(int, const struct shmaddr *, int);
int   shmctl(int, int, struct shmid_ds *);
int   shmdt(struct shmaddr *);
int   shmget(key_t, size_t, int);

%rename(shmread) inner_shmread;
%inline %{
static VALUE
inner_shmread(const struct shmaddr *shmaddr, size_t len, size_t offset)
{
    return rb_str_new((char *) shmaddr + offset, len);
}
%}

%rename(shmwrite) inner_shmwrite;
%inline %{
static VALUE
inner_shmwrite(struct shmaddr *shmaddr, VALUE data, size_t offset)
{
    VALUE s;

    s = rb_check_string_type(data);
    memcpy((char *) shmaddr + offset, RSTRING(s)->ptr, RSTRING(s)->len);
    
    return Qnil;
}
%}

