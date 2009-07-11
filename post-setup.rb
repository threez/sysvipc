$:.unshift('ext')
$:.unshift('lib')

require 'fileutils'
require 'rubygems'
require 'time'
require 'SysVIPC'

GEM = 'SysVIPC'
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
  rdoc_time = Time.parse(File.open(DOC_TIME_FILE).read)
rescue
  rdoc_time = Time.local(1970)
end

unless File.exist?(NODOC)
  system "rdoc --title #{GEM} --force-update #{DOC_SOURCE.join(' ')}" if DOC_SOURCE.any? do |s|
    File.stat(s).mtime > rdoc_time
  end
end

# Build Gem.

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = SysVIPC::RELEASE.sub(/-rc\d+\z/,'')
  s.summary = "Builders for MarkUp."
  s.description = %{System V Inter-Process Communication: message queues, semaphores, and shared memory.}
  s.extensions << './ext/extconf.rb'
  s.files = Dir['lib/**/*.rb'] + Dir['ext/**/*.c'] + Dir['test/**/*.rb']
  s.require_path = 'lib'
  s.has_rdoc = true
  s.rdoc_options << '--title' <<  GEM
  s.homepage = 'http://rubyforge.org/projects/sysvipc/'
  s.rubyforge_project = 'sysvipc'
  s.author = 'Steven Jenkins'
  s.email = 'sjenkins@rubyforge.org'
end

Gem::Builder.new(spec).build
