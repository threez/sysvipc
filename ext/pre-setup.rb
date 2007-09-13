basename = 'SysVIPC'

ifile = basename + '.i'
cfile = basename + '.c'

unless File.file?(cfile) and
    File.mtime(cfile) >= File.mtime(ifile)
	system "swig -ruby -o #{cfile} #{ifile}"
end
