require 'MrMurano/Solution-Cors'

command :cors do |c|
  c.syntax = %{mr cors [options]}
  c.description = %{Get or set the CORS for the solution.}
  c.option '-f','--file FILE', String, %{File to set CORS from}

  c.action do |args,options|
    sol = MrMurano::Cors.new

    if options.file then
      #set
      pp sol.upload(options.file, {})
    else
      # get
      ret = sol.fetch()
      puts ret
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
