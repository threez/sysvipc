%module SysVIPC

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

#ifndef HAVE_UNION_SEMUN
union semun {
    int              val;
    struct semid_ds *buf;
    unsigned short  *array;
};
#endif

struct Semun {
    int              val;
    struct semid_ds *buf;
    unsigned short  *array;
};

%}

%include typemaps.i

/* globals */

extern const int errno;

/*
 * sys/types.h
 */

/* typedefs */

typedef unsigned gid_t;
typedef unsigned key_t;
typedef unsigned mode_t;
typedef unsigned pid_t;
typedef unsigned uid_t;
#if 0
typedef int size_t;
typedef int time_t;
#endif

/*
 * sys/ipc.h
 */

/* constants */

%init %{
#define def_const(name) rb_define_const(mSysVIPC, #name, SWIG_From_int(name))

  def_const(IPC_CREAT);
  def_const(IPC_EXCL);
  def_const(IPC_NOWAIT);

  def_const(IPC_PRIVATE);

  def_const(IPC_RMID);
  def_const(IPC_SET);
  def_const(IPC_STAT);
%}

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

%init %{
    def_const(MSG_NOERROR);
%}

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

/* functions */

int       msgctl(int, int, struct msqid_ds *);
int       msgget(key_t, int);
ssize_t   msgrcv(int, void *, size_t, long int, int);
int       msgsnd(int, const void *, size_t, int);

/*
 * sys/sem.h
 */

/* constants */

%init %{
    def_const(SEM_UNDO);

    def_const(GETNCNT);
    def_const(GETPID);
    def_const(GETVAL);
    def_const(GETALL);
    def_const(GETZCNT);
    def_const(SETVAL);
    def_const(SETALL);
%}

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

%typemap(in) unsigned short [ANY] {
  unsigned short *ap;
  int i, len;

  Check_Type($input, T_ARRAY);
  len = RARRAY($input)->len;
  $1 = ap = ALLOC_N(unsigned short, len);
  *(ap++) = len;
  for (i = 0; i < len; i++) {
    *(ap++) = NUM2INT(rb_ary_entry($input, i));
  }
}

%typemap(memberin) unsigned short [ANY] {
  free($1);
  $1 = $input;
}

%typemap(out) unsigned short [ANY] {
  int i, len;

  len = *($1++);
  $result = rb_ary_new2(len);
  for (i = 0; i < len; i++) {
    rb_ary_store($result, i, INT2FIX(*($1++)));
  }
}

%{
#ifdef HAVE_RB_DEFINE_ALLOC_FUNC
static VALUE
_wrap_Semun_allocate(VALUE self) {
#else
  static VALUE
  _wrap_Semun_allocate(int argc, VALUE *argv, VALUE self) {
#endif
    
    
    VALUE vresult = SWIG_NewClassInstance(self, SWIGTYPE_p_Semun);
#ifndef HAVE_RB_DEFINE_ALLOC_FUNC
    rb_obj_call_init(vresult, argc, argv);
#endif
    return vresult;
  }
  
static VALUE
_wrap_new_Semun(int argc, VALUE *argv, VALUE self) {
  struct Semun *result = 0 ;
  
  if ((argc < 0) || (argc > 0)) {
    rb_raise(rb_eArgError, "wrong # of arguments(%d for 0)",argc); SWIG_fail;
  }
  result = (struct Semun *)(struct Semun *) calloc(1, sizeof(struct Semun));DATA_PTR(self) = result;
  result->array = (unsigned short *) calloc(1, sizeof(unsigned short));
  
  return self;
fail:
  return Qnil;
}

static void
free_Semun(struct Semun *arg1) {
    free((char *) arg1->array);
    free((char *) arg1);
}
%}

%nodefaultctor Semun;
%nodefaultdtor Semun;

struct Semun {
    int              val;
    struct semid_ds *buf;
    unsigned short  array[];
};

%init %{
  rb_define_method(cSemun.klass, "initialize", _wrap_new_Semun, -1);
  rb_define_alloc_func(cSemun.klass, _wrap_Semun_allocate);
%}

%typemap(default) struct Semun {
    $1.val = 0;
    $1.buf = NULL;
    $1.array = (unsigned short *) calloc(1, sizeof(unsigned short));
}

/* functions */

%rename(semctl) inner_semctl;
%inline %{
static VALUE inner_semctl(int semid, int semnum, int cmd, struct Semun arg)
{
    union semun us;

    switch (cmd) {
    case SETVAL:
        us.val = arg.val;
        break;
    case SETALL:
    case GETALL:
        us.array = arg.array + 1;
        break;
    case IPC_STAT:
    case IPC_SET:
        us.buf = arg.buf;
        break;
    }
    return INT2FIX(semctl(semid, semnum, cmd, us));
}
%}

int   semget(key_t, int, int);

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

typedef unsigned int shmatt_t;

/* constants */

const int SHM_RDONLY;
const int SHMLBA;
const int SHM_RND;

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

/* functions */

void *shmat(int, const void *, int);
int   shmctl(int, int, struct shmid_ds *);
int   shmdt(const void *);
int   shmget(key_t, size_t, int);

