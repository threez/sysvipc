require 'SysVIPC.so'

module SysVIPC

  RELEASE = '0.9.1-rc1'

  class Semaphore

    def initialize(key, nsems, flags)
      @nsems = nsems
      @semid = semget(key, nsems, flags)
      raise SystemCallError.new(SysVIPC.errno) if @semid == -1
    end

    def setall(values)
      if values.length > @nsems
	raise ArgumentError,
	  "too many values(#{values.length} for semaphore set (#{@nsems})"
      end
      su = Semun.new
      su.array = values
      status = semctl(@semid, 0, SETALL, su)
      raise SystemCallError.new(SysVIPC.errno) if status == -1
    end

    def getall
      su = Semun.new
      su.array = Array.new(@nsems, 0)
      status = semctl(@semid, 0, GETALL, su)
      raise SystemCallError.new(SysVIPC.errno) if status == -1
      su.array
    end

    def setval(semnum, val)
      su = Semun.new
      su.val = SEMVAL
      status = semctl(@semid, semnum, SETVAL, su)
      raise SystemCallError.new(SysVIPC.errno) if status == -1
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
      status = semctl(@semid, 0, IPC_STAT, su)
      raise SystemCallError.new(SysVIPC.errno) if status == -1
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
      status = semctl(@semid, 0, IPC_SET, su)
      raise SystemCallError.new(SysVIPC.errno) if status == -1
    end

    def ipc_rmid
      status = semctl(@semid, 0, IPC_RMID)
      raise SystemCallError.new(SysVIPC.errno) if status == -1
    end
    alias :rm :ipc_rmid

    def op(array)
      status = semop(@semid, array, array.length)
      raise SystemCallError.new(SysVIPC.errno) if status == -1
    end

  end

end

