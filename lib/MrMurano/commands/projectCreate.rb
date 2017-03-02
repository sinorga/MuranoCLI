require 'MrMurano/Account'

command 'project create' do |c|
  c.syntax = %{murano project create <name>}
  c.summary = %{Create a new project}
  c.option '--save', %{Save new project id to config}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Name of project missing"
      return
    end
    name = args[0]

    ret = acc.new_project(name)
    if not ret.kind_of?(Hash) and not ret.empty? then
      acc.error "Create failed: #{ret.to_s}"
      return
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.projects.select{|i| i[:domain] =~ /#{name}\./}
    pid = ret.first[:apiId]
    if options.save then
      $cfg.set('project.id', pid)
    end
    acc.outf pid

  end
end
#  vim: set ai et sw=2 ts=2 :
