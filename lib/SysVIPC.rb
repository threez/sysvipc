require 'SysVIPC.so'

module SysVIPC

  def check_result(res)               # :nodoc:
    raise SystemCallError.new(SysVIPC.errno), nil, caller if res == -1
  end

  class MessageQueue

    private

    # Return a MessageQueue object encapsuating a message queue
    # associated with +key+. See msgget(2).

    def initialize(key, flags = 0)
      @msgid = msgget(key, flags)
      check_result(@msgid)
    end

    public

    # Return the Msqid_ds object. See msgctl(2).

    def ipc_stat
      msqid_ds = Msqid_ds.new
      check_result(msgctl(@msgid, IPC_STAT, msqid_ds))
      msqid_ds
    end
    alias :msqid_ds :ipc_stat

    # Set the Msqid_ds object. See msgctl(2).

    def ipc_set(msqid_ds)
      unless Msqid_ds === msqid_ds
	raise ArgumentError,
	  "argument to ipc_set must be a Msqid_ds"
      end
      check_result(msgctl(@msgid, IPC_SET, msqid_ds))
    end
    alias :msqid_ds= :ipc_set

    # Remove. See msgctl(2).

    def ipc_rmid
      check_result(msgctl(@msgid, IPC_RMID, nil))
    end
    alias :rm :ipc_rmid

    # Send a message with type +type+ and text +text+. See msgsnd(2).

    def snd(type, text, flags = 0)
      msgbuf = Msgbuf.new
      msgbuf.mtype = type
      msgbuf.mtext = text
      check_result(msgsnd(@msgid, msgbuf, text.length, flags))
    end
    alias :send :snd

    # Receive a message of type +type+, limited to +len+ bytes or fewer.
    # See msgsnd(2).

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

    # Return a SharedMemory object encapsulating a
    # shared memory segment of +size+ bytes associated with
    # +key+. See shmget(2).

    def initialize(key, size, flags = 0)
      @shmid = shmget(key, size, flags)
      check_result(@shmid)
    end

    public

    # Return the Shmid_ds object. See shmctl(2).

    def ipc_stat
      shmid_ds = Shmid_ds.new
      check_result(shmctl(@shmid, IPC_STAT, shmid_ds))
      shmid_ds
    end
    alias :shmid_ds :ipc_stat

    # Set the Shmid_ds object. See shmctl(2).

    def ipc_set(shmid_ds)
      unless Shmid_ds === shmid_ds
	raise ArgumentError,
	  "argument to ipc_set must be a Shmid_ds"
      end
      check_result(shmctl(@shmid, IPC_SET, shmid_ds))
    end
    alias shmid_ds= :ipc_set

    # Remove. See shmctl(2).

    def ipc_rmid
      check_result(shmctl(@shmid, IPC_RMID, nil))
    end
    alias :rm :ipc_rmid

    # Attach to a shared memory address object and return it.
    # See shmat(2). If +shmaddr+ is nil, the shared memory is attached
    # at the first available address as selected by the system. See
    # shmat(2).

    def attach(shmaddr = nil, flags = 0)
      shmaddr = shmat(@shmid, shmaddr, flags)
      check_result(shmaddr)
      shmaddr
    end

    # Detach the +Shmaddr+ object +shmaddr+. See shmdt(2).

    def detach(shmaddr)
      check_result(shmdt(shmaddr))
    end

  end

  class Shmaddr

    # Write the string +text+ to offset +offset+.

    def write(text, offset = 0)
      shmwrite(self, text, offset)
    end
    alias :<< :write

    # Read +len+ bytes at offset +offset+ and return them in a String.

    def read(len, offset = 0)
      shmread(self, len, offset)
    end

  end

end
