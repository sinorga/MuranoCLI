
command :syncdown do |c|
  c.syntax = %{mr syncdown [options]}
  c.description = %{Sync project down from Murano}
  c.option '--endpoints', %{Sync Endpoints}
  c.option '--modules', %{Sync Modules}
  c.option '--eventhandlers', %{Sync Event Handlers}
  c.option '--roles', %{Sync Roles}
  c.option '--users', %{Sync Users}
  c.option '--files', %{Sync Static Files}

  c.option '--[no-]delete', %{Don't delete things from server}
  c.option '--[no-]create', %{Don't create things on server}
  c.option '--[no-]update', %{Don't update things on server}

  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true

    if options.all then
      options.files = true
      options.endpoints = true
      options.modules = true
      options.roles = true
      options.users = true
      options.eventhandlers = true
    end
    
    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.syncdown($cfg['location.base'] + $cfg['location.endpoints'], options)
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.modules'], options)
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.eventhandlers'], options)
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.roles'], options)
    end

    if options.users then
      sol = MrMurano::User.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.users'], options)
    end

    if options.files then
      sol = MrMurano::File.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.files'], options)
    end

  end
end
alias_command :pull, :syncdown, '--no-delete'

command :syncup do |c|
  c.syntax = %{mr syncup [options]}
  c.description = %{Sync project up into Murano}
  c.option '--all', 'Sync everything'
  c.option '--endpoints', %{Sync Endpoints}
  c.option '--modules', %{Sync Modules}
  c.option '--eventhandlers', %{Sync Event Handlers}
  c.option '--roles', %{Sync Roles}
  c.option '--users', %{Sync Users}
  c.option '--files', %{Sync Static Files}

  c.option '--[no-]delete', %{Don't delete things from server}
  c.option '--[no-]create', %{Don't create things on server}
  c.option '--[no-]update', %{Don't update things on server}

  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true

    if options.all then
      options.files = true
      options.endpoints = true
      options.modules = true
      options.roles = true
      options.users = true
      options.eventhandlers = true
    end

    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.syncup($cfg['location.base'] + $cfg['location.endpoints'], options)
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.syncup( $cfg['location.base'] + $cfg['location.modules'], options)
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.syncup( $cfg['location.base'] + $cfg['location.eventhandlers'], options)
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.syncup( $cfg['location.base'] + $cfg['location.roles'], options)
    end

    if options.users then
      sol = MrMurano::User.new
      sol.syncup( $cfg['location.base'] + $cfg['location.users'], options)
    end

    if options.files then
      sol = MrMurano::File.new
      sol.syncup( $cfg['location.base'] + $cfg['location.files'], options)
    end

  end
end
alias_command :push, :syncup, '--no-delete'

#  vim: set ai et sw=2 ts=2 :
