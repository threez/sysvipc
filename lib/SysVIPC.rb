require 'SysVIPC.so'

module SysVIPC

  RELEASE = '0.9.1-rc1'

  def check_result(res)
    raise SystemCallError.new(SysVIPC.errno), nil, caller if res == -1
  end

  class MessageQueue

    private

    def initialize(key, flags)
      @msgid = msgget(key, flags)
      check_result(@msgid)
    end

    public

    def ipc_stat
      msqid_ds = Msqid_ds.new
      check_result(msgctl(@msgid, IPC_STAT, msqid_ds))
      msqid_ds
    end
    alias :msqid_ds :ipc_stat

    def ipc_set(msqid_ds)
      unless Msqid_ds === msqid_ds
	raise ArgumentError,
	  "argument to ipc_set must be a Msqid_ds"
      end
      check_result(msgctl(@msgid, IPC_SET, msqid_ds))
    end

    def ipc_rmid
      check_result(msgctl(@msgid, IPC_RMID, nil))
    end
    alias :rm :ipc_rmid

    def snd(type, text, flags = 0)
      msgbuf = Msgbuf.new
      msgbuf.mtype = type
      msgbuf.mtext = text
      check_result(msgsnd(@msgid, msgbuf, text.length, flags))
    end
    alias :send :snd

    def rcv(type, size, flags = 0)
      msgbuf = Msgbuf.new
      msgbuf.mtype = type
      msgbuf.mtext = ' ' * size
      check_result(msgrcv(@msgid, msgbuf, size, type, flags))
      msgbuf.mtext
    end
    alias :receive :rcv

  end

  class Semaphore

    private

    def initialize(key, nsems, flags)
      @nsems = nsems
      @semid = semget(key, nsems, flags)
      check_result(@semid)
    end

    public

    def setall(values)
      if values.length > @nsems
	raise ArgumentError,
	  "too many values(#{values.length} for semaphore set (#{@nsems})"
      end
      su = Semun.new
      su.array = values
      check_result(semctl(@semid, 0, SETALL, su))
    end

    def getall
      su = Semun.new
      su.array = Array.new(@nsems, 0)
      check_result(semctl(@semid, 0, GETALL, su))
      su.array
    end

    def setval(semnum, val)
      su = Semun.new
      su.val = SEMVAL
      check_result(semctl(@semid, semnum, SETVAL, su))
    end

    def getval(semnum)
      semctl(@semid, semnum, GETVAL)
    end
    alias :val :getval

    def getpid
      semctl(@semid, 0, GETPID)
    end
    alias :pid :getpid

    def getncnt
      semctl(@semid, 0, GETNCNT)
    end
    alias :ncnt :getncnt

    def getzcnt
      semctl(@semid, 0, GETZCNT)
    end
    alias :zcnt :getzcnt

    def ipc_stat
      su = Semun.new
      su.buf = Semid_ds.new
      check_result(semctl(@semid, 0, IPC_STAT, su))
      su.buf
    end
    alias :semid_ds :ipc_stat

    def ipc_set(semid_ds)
      unless Semid_ds === semid_ds
	raise ArgumentError,
	  "argument to ipc_set must be a Semid_ds"
      end
      su = Semun.new
      su.buf = semid_ds
      check_result(semctl(@semid, 0, IPC_SET, su))
    end

    def ipc_rmid
      check_result(semctl(@semid, 0, IPC_RMID))
    end
    alias :rm :ipc_rmid

    def op(array)
      check_result(semop(@semid, array, array.length))
    end

  end

  class SharedMemory
    
    private

    def initialize(key, size, flags)
      @shmid = shmget(key, size, flags)
      check_result(@shmid)
    end

    public

    def ipc_stat
      shmid_ds = Shmid_ds.new
      check_result(shmctl(@shmid, IPC_STAT, shmid_ds))
      shmid_ds
    end
    alias :shmid_ds :ipc_stat

    def ipc_set(shmid_ds)
      unless Shmid_ds === shmid_ds
	raise ArgumentError,
	  "argument to ipc_set must be a Shmid_ds"
      end
      check_result(shmctl(@shmid, IPC_SET, shmid_ds))
    end

    def ipc_rmid
      check_result(shmctl(@shmid, IPC_RMID, nil))
    end
    alias :rm :ipc_rmid

  end

end

