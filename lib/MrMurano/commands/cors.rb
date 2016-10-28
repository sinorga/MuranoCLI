require 'yaml'
require 'MrMurano/Solution-Cors'

command :cors do |c|
  c.syntax = %{mr cors [options]}
  c.summary = %{Get or set the CORS for the solution. [Depercated]}
  c.description = %{Get or set the CORS for the solution.

This is deprecated.  Use `mr syncup --cors` or `mr syncdown --cors` instead.
  }
  c.option '-f','--file FILE', String, %{File to set CORS from}

  c.action do |args,options|
    say_warning "This is deprecated.  Use `mr syncup --cors` or `mr syncdown --cors` instead."
    sol = MrMurano::Cors.new

    if options.file then
      #set
      data = sol.localitems(options.file)
      pp sol.upload(options.file, data.first)
    else
      # get
      ret = sol.fetch()
      puts ret.to_yaml
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
