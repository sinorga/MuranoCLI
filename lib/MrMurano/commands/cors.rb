require 'yaml'
require 'MrMurano/Solution-Cors'

command :cors do |c|
  c.syntax = %{murano cors}
  c.summary = %{Get the CORS for the project.}
  c.description = %{Get the CORS for the project.

  Set the CORS with `murano cors set`
  }

  c.action do |args,options|
    sol = MrMurano::Cors.new
    ret = sol.fetch()
    sol.outf ret
  end
end

command 'cors set' do |c|
  c.syntax = %{murano cors set [<file>]}
  c.summary = %{Set the CORS for the project.}

  c.action do |args,options|
    crs = MrMurano::Cors.new
    file = args.shift
    crs.upload(file)
  end
end

#  vim: set ai et sw=2 ts=2 :
