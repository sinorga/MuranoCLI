
command :status do |c|
  c.syntax = %{mr status [options]}
  c.description = %{Get the status of files}
  c.option '--all', 'Check everything'
  c.option '-s','--files', %{Static Files}
  c.option '-a','--endpoints', %{Endpoints}
  c.option '-m','--modules', %{Modules}
  c.option '-e','--eventhandlers', %{Event Handlers}
  c.option '--roles', %{Roles}
  c.option '--users', %{Users}

  c.option '--[no-]asdown', %{Report as if syncdown instead of syncup}
  c.option '--[no-]diff', %{For modified items, show a diff}
  c.option '--[no-]grouped', %{Group all adds, deletes, and mods together}
  
  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true, :diff=>false, :grouped => true

    if options.all then
      options.files = true
      options.endpoints = true
      options.modules = true
      options.roles = true
      options.users = true
      options.eventhandlers = true
    end

    def fmtr(item)
      if item.has_key? :local_path then
        item[:local_path].relative_path_from(Pathname.pwd()).to_s
      else
        item[:synckey]
      end
    end
    def pretty(ret, options)
      say "Adding:" if options.grouped
      ret[:toadd].each{|item| say " + #{item[:pp_type]}  #{fmtr(item)}"}
      say "Deleteing:" if options.grouped
      ret[:todel].each{|item| say " - #{item[:pp_type]}  #{fmtr(item)}"}
      say "Changing:" if options.grouped
      ret[:tomod].each{|item|
        say " M #{item[:pp_type]}  #{fmtr(item)}"
        say item[:diff] if options.diff
      }
    end

    @grouped = {:toadd=>[],:todel=>[],:tomod=>[]}
    def gmerge(ret, type, options)
      if options.grouped then
        [:toadd, :todel, :tomod].each do |kind|
          ret[kind].each{|item| item[:pp_type] = type; @grouped[kind] << item}
        end
      else
        pretty(ret, options)
      end
    end
    
    if options.endpoints then
      sol = MrMurano::Endpoint.new
      ret = sol.status($cfg['location.base'] + $cfg['location.endpoints'], options)
      gmerge(ret, ' EP ', options)
    end

    if options.modules then
      sol = MrMurano::Library.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.modules'], options)
      gmerge(ret, 'MOD ', options)
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.eventhandlers'], options)
      gmerge(ret, ' EH ', options)
    end

    if options.roles then
      sol = MrMurano::Role.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.roles'], options)
      gmerge(ret, 'ROLE', options)
    end

    if options.users then
      sol = MrMurano::User.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.users'], options)
      gmerge(ret, 'USER', options)
    end

    if options.files then
      sol = MrMurano::File.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.files'], options)
      gmerge(ret, 'FILE', options)
    end

    pretty(@grouped, options) if options.grouped
  end
end

alias_command :diff, :status, '--diff', '--no-grouped'

#  vim: set ai et sw=2 ts=2 :
