require 'yaml'
require 'MrMurano/Solution-Cors'

command :cors do |c|
  c.syntax = %{murano cors [options]}
  c.summary = %{Get or set the CORS for the solution. [Deprecated]}
  c.description = %{Get or set the CORS for the solution.

This is deprecated.  Use `murano syncup --cors` or `murano syncdown --cors` instead.
  }
  c.option '-f','--file FILE', String, %{File to set CORS from}

  c.action do |args,options|
    say_warning "This is deprecated.  Use `murano syncup --cors` or `murano syncdown --cors` instead."
    sol = MrMurano::Cors.new

    if options.file then
      #set
      data = sol.localitems(options.file)
      sol.outf sol.upload(options.file, data.first)
    else
      # get
      ret = sol.fetch()
      sol.outf ret
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
