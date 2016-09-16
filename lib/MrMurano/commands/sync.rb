
command :syncdown do |c|
  c.syntax = %{mr syncdown [options]}
  c.description = %{Sync project down from Murano}
  c.option '--all', 'Sync everything'
  c.option '-s','--[no-]files', %{Sync Static Files}
  c.option '-a','--[no-]endpoints', %{Sync Endpoints}
  c.option '-m','--[no-]modules', %{Sync Modules}
  c.option '-e','--[no-]eventhandlers', %{Sync Event Handlers}
  c.option '--roles', %{Sync Roles}
  c.option '--users', %{Sync Users}

  c.option '--[no-]delete', %{Don't delete things from server}
  c.option '--[no-]create', %{Don't create things on server}
  c.option '--[no-]update', %{Don't update things on server}

  c.example %{Make local be like what is on the server}, %{mr syncdown --all}
  c.example %{Pull down new things, but don't delete or modify anything}, %{mr syncdown --all --no-delete --no-update}
  c.example %{Only Pull new static files}, %{mr syncdown --files --no-delete --no-update}
  
  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true
    MrMurano.checkSAME(options)
    
    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.syncdown(options)
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.syncdown(options)
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.syncdown(options)
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.syncdown(options)
    end

    if options.users then
      sol = MrMurano::User.new
      sol.syncdown(options)
    end

    if options.files then
      sol = MrMurano::File.new
      sol.syncdown(options)
    end

  end
end
alias_command :pull, :syncdown, '--no-delete'

command :syncup do |c|
  c.syntax = %{mr syncup [options]}
  c.description = %{Sync project up into Murano}
  c.option '--all', 'Sync everything'
  c.option '-s','--[no-]files', %{Sync Static Files}
  c.option '-a','--[no-]endpoints', %{Sync Endpoints}
  c.option '-m','--[no-]modules', %{Sync Modules}
  c.option '-e','--[no-]eventhandlers', %{Sync Event Handlers}
  c.option '--roles', %{Sync Roles}
  c.option '--users', %{Sync Users}

  c.option '--[no-]delete', %{Don't delete things from server}
  c.option '--[no-]create', %{Don't create things on server}
  c.option '--[no-]update', %{Don't update things on server}

  c.example %{Deploy project to server}, %{mr syncup --all}
  c.example %{Update static files}, %{mr syncup --files}
  c.example %{Only add or modify static files}, %{mr syncup --files --no-delete}

  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true
    MrMurano.checkSAME(options)

    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.syncup(options)
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.syncup(options)
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.syncup(options)
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.syncup(options)
    end

    if options.users then
      sol = MrMurano::User.new
      sol.syncup(options)
    end

    if options.files then
      sol = MrMurano::File.new
      sol.syncup(options)
    end

  end
end
alias_command :push, :syncup, '--no-delete'

#  vim: set ai et sw=2 ts=2 :
