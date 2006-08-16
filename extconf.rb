require 'mkmf'

# This modified verion of have_type uses a check adapted from GNU
# autoconf 2.59. It prevents false negatives caused by optimization in
# gcc 4.x.

def have_type(type, header = nil, opt = "", &b)
  checking_for type do
    header = cpp_include(header)
    if try_compile(<<"SRC", opt, &b) or (/\A\w+\z/n =~ type && try_compile(<<"SRC", opt, &b))
#{COMMON_HEADERS}
#{header}
/*top*/
int
main ()
{
if ((#{type} *) 0)
  return 0;
if (sizeof (#{type}))
  return 0;
  ;
  return 0;
}
SRC
#{COMMON_HEADERS}
#{header}
/*top*/
int
main ()
{
if ((#{type} *) 0)
  return 0;
if (sizeof (#{type}))
  return 0;
  ;
  return 0;
}
SRC
      $defs.push(format("-DHAVE_TYPE_%s", type.strip.upcase.tr_s("^A-Z0-9_", "_")))
      true
    else
      false
    end
  end
end

have_type('struct msgbuf', 'sys/msg.h')
have_type('union semun', 'sys/sem.h')

if have_header('sys/types.h') and have_header('sys/ipc.h') and
    have_header('sys/msg.h') and have_func('msgget') and
    have_header('sys/sem.h') and have_func('semget') and
    have_header('sys/shm.h') and have_func('shmget')
  create_makefile('sysvipc')
end
