require 'mkmf'

# This modified verion of have_type uses a check suggested by Nobu
# Nakada.  It prevents false detection of nonexistent types caused
# by optimization in gcc 4.x. Mkmf in versions 1.9 and later
# apparently fixes the problem.

major, minor = RUBY_VERSION.split(/\./).map { |n| n.to_i }
ok =  (major > 1) or (major == 1 and minor > 8)
unless ok
  def have_type(type, header = nil, opt = "", &b)
    checking_for type do
      header = cpp_include(header)
      if try_compile(<<"SRC", opt, &b)
#{COMMON_HEADERS}
#{header}
/*top*/
int
main ()
{
    typedef #{type} conftest_type;
    int conftestval[sizeof(conftest_type)?1:-1];
    int main() {return 0;}
    int t() {return conftestval[0];}
}
SRC
	$defs.push(format("-DHAVE_TYPE_%s", type.strip.upcase.tr_s("^A-Z0-9_", "_")))
	true
      else
	false
      end
    end
  end
end

have_type('struct msgbuf', 'sys/msg.h')
have_type('union semun', 'sys/sem.h')

if have_header('sys/types.h') and have_header('sys/ipc.h') and
    have_header('sys/msg.h') and have_func('msgget') and
    have_header('sys/sem.h') and have_func('semget') and
    have_header('sys/shm.h') and have_func('shmget')
  create_makefile('SysVIPC')
end
