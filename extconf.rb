require 'mkmf'

if have_header ('sys/types.h') and have_header ('sys/ipc.h') and
    have_header ('sys/msg.h') and have_func ('msgget') and
    have_header ('sys/sem.h') and have_func ('semget') and
    have_header ('sys/shm.h') and have_func ('shmget')
  create_makefile ('sysvipc')
end
