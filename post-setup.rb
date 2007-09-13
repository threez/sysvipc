$:.unshift('ext')
$:.unshift('lib')

require 'fileutils'
require 'parsedate'
require 'SysVIPC'

PACKAGE = 'ruby-sysvipc'
DOC_SOURCE = %w{ext/SysVIPC.c lib/SysVIPC.rb}
DOC_TIME_FILE = 'doc/created.rid'
NODOC = '.nodoc'

pv = PACKAGE + '-' + SysVIPC::RELEASE

# Make directory for building distribution files.

FileUtils.rm_rf(pv)
FileUtils.mkdir(pv)

# Copy files into distribution directory.

File.open('MANIFEST').each do |file|
    file.chomp!
    dir = File.dirname file
    subdir = pv + '/' + dir
    unless File.directory?(subdir)
	FileUtils.mkdir_p(subdir)
    end
    dest = pv + '/' + file
    FileUtils.cp(file, dest)
end

# Make distribution files.

system "tar czf #{pv}.tar.gz #{pv}"
system "zip -rq #{pv}.zip #{pv}"

# Clean up.

FileUtils.rm_rf(pv)

# Create HTML documentation if out of date.

begin
  rdoc_time = Time.local(*ParseDate.parsedate(File.open(DOC_TIME_FILE).read))
rescue
  rdoc_time = Time.local(1970)
end

unless File.exist?(NODOC)
  system "rdoc #{DOC_SOURCE.join(' ')}" if DOC_SOURCE.any? do |s|
    File.stat(s).mtime > rdoc_time
  end
end
