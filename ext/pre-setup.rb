basename = 'SysVIPC'

ifile = basename + '.i'
cfile = basename + '.c'

unless File.file?(cfile) and
    File.mtime(cfile) >= File.mtime(ifile)
	system "swig -ruby -w-801 -o #{cfile} #{ifile}"
end
