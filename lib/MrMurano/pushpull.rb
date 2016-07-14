

command :pull do |c|
  c.syntax = %{mr pull}
  c.description = %{For a project, pull a copy of everything down.}
  c.option '--overwrite', 'Replace local files.'

  c.option '--all', 'Pull everything'
  c.option '--files', 'Pull static files down'
  c.option '--endpoints', 'Pull endpoints down'
  c.option '--modules', 'Pull modules down'
  c.option '--eventhandlers', 'Pull eventhandlers down'
  c.option '--roles', 'Pull roles down'
  c.option '--users', 'Pull users down'

  c.action do |args, options|

    if options.all then
      options.files = true
      options.endpoints = true
      options.modules = true
      options.roles = true
      options.users = true
      options.eventhandlers = true
    end

    if options.files then
      sol = MrMurano::File.new
      sol.pull( $cfg['location.base'] + $cfg['location.files'], options.overwrite )
    end

    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.pull( $cfg['location.base'] + $cfg['location.endpoints'], options.overwrite )
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.pull( $cfg['location.base'] + $cfg['location.modules'], options.overwrite )
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.pull( $cfg['location.base'] + $cfg['location.roles'], options.overwrite )
    end

    if options.users then
      sol = MrMurano::User.new
      sol.pull( $cfg['location.base'] + $cfg['location.users'], options.overwrite )
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.pull( $cfg['location.base'] + $cfg['location.eventhandlers'], options.overwrite )
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
