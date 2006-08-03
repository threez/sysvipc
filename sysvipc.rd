=begin

= sysvipc

The extension library to use System V IPC system calls from Ruby.
It provides a simple object interface to message queues, semaphore sets,
and shared memory segments.

== Class/Module
* ((<SystemVIPC>)) (module)
  * ((<Error>))
  * ((<IPCObject>))
    * ((<MessageQueue>))
    * ((<Semaphore>))
    * ((<SharedMemory>))
  * ((<SemaphoreOperation>))
  * ((<Permission>))

== SystemVIPC

SystemVIPC is the module which provides the other features in System V IPC.
See ipc(5) for more details.

=== module function

--- ftok(path, id)
    Convert a path of an existing accessible file and an identifier to
    a System V IPC key.

== Error

SystemVIPC::Error is exception class.  While doing some sanity checks
before calling real system calls, errors are reported by this class.

=== super class

StandardError

== IPCObject

The root interface in the System V IPC classes hierarchy.

=== super class

Object

=== method

--- IPCObject#remove
    Request the kernel to remove immediately the current IPC object.

=== MessageQueue

Provides an object interface to using System V IPC message queue.

==== super class

((<IPCObject>))

==== class method

--- MessageQueue.new(key[,flags])
    Returns a message queue associated with key.  If no existing queue
    is associated to key, and IPC_CREAT is asserted in flags, a new
    queue is created.

==== method

--- MessageQueue#send(type,buf[,flags])
    Place a message on the queue with the data from buf and with type.
    The constants for flags are defined in ((<SystemVIPC>)) module.

--- MessageQueue#recv(type,len[,flags])
    Receives data from the queue and returns as an string.
    The constants for flags are defined in ((<SystemVIPC>)) module.

=== Semaphore

Provides an object interface to using System V IPC semaphores.

==== super class

((<IPCObject>))

==== class method

--- Semaphore.new(key[,nsems,flags])
    Returns a semaphore set associated with key.  If no existing
    semaphore set is associated to key, and IPC_CREAT is asserted in
    flags, a new set of nsems semaphores is created.
    The constants for flags are defined in ((<SystemVIPC>)) module.

==== method

--- Semaphore#to_a
    Returns the values of the semaphore set as an array.

--- Semaphore#set_all(ary)
    Sets all values in the semaphore set to those given on ary.
    ary must contain the correct number of values.

--- Semaphore#value(pos)
    Returns the current value of the semaphore given as pos.

--- Semaphore#set_value(pos,v)
    Set the value of the semaphore given as pos to v.

--- Semaphore#n_count(pos)
    Returns the number of processed waiting for the semaphore given as
    pos to become greater than its current value.

--- Semaphore#z_count(pos)
    Returns the number of processed waiting for the semaphore given as
    pos to become zero.

--- Semaphore#pid(pos)
    Returns the process id of the last process that performed an operation
    on the semaphore given as pos.

--- Semaphore#size
    Returns the number of semaphores.

--- Semaphore#apply(ops)
    Applies all of the semaphore operations given on ops. The argument
    ops is an array of ((<SemaphoreOperation>)).

=== SharedMemory

Provides an object interface to using System V IPC shared memory.

==== super class

((<IPCObject>))

==== class method

--- SharedMemory.new(key[,nsems,flags])
    Returns a shared memory segment associated with key.  If no
    existing memory is associated to key, and IPC_CREAT is asserted in
    flags, a new shared memory segment is created.
    The constants for flags are defined in ((<SystemVIPC>)) module.

==== method

--- SharedMemory#attach([flags])
    Attaches the shared memory segment.

--- SharedMemory#detach
    Detaches the shared memory segment.

--- SharedMemory#read([len])
    Returns a string of bytes peeked from the shared memory segment.

--- SharedMemory#write(string)
    Writes a string to the shared memory segment.

--- SharedMemory#size
    Returns size of segment in bytes.

=== SemaphoreOperation

Provides an object to represent semaphore operation.

==== super class

Object

==== class method

--- SemaphoreOperation.new (pos,value[,flags])
    Returns an operation to be performed on a semaphore.

==== method

--- SemaphoreOperation#pos
    Returns the semaphore number.

--- SemaphoreOperation#value
    Returns the value of the semaphore operation.

--- SemaphoreOperation#flags
    Returns the operation flags.

=== Permission

Provides an object to represent permissions of IPC objects.

==== super class

Object

==== class method

--- Permission.new(ipc)
    Returns a permission information extracted from ipc.  The argument
    ipc is an instance of the class ((<IPCObject>)).

==== method

--- Permission#cuid
    Returns the user id of the creator.

--- Permission#cgid
    Returns the group id of the creator.

--- Permission#uid
    Returns the user id of the owner.

--- Permission#gid
    Returns the group id of the owner.

--- Permission#mode
    Returns the read/write permission.

=end
