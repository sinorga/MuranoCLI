
command :status do |c|
  c.syntax = %{mr status [options]}
  c.description = %{Get the status of files}
  c.option '--all', ' everything'
  c.option '--endpoints', %{Endpoints}
  c.option '--modules', %{Modules}
  c.option '--eventhandlers', %{Event Handlers}
  c.option '--roles', %{Roles}
  c.option '--users', %{Users}
  c.option '--files', %{Static Files}

  c.option '--asdown', %{Report as if syncdown instead of syncup}
  
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

    def fmtr(item)
      if item.has_key? :local_path then
        item[:local_path].relative_path_from(Pathname.pwd()).to_s
      else
        item[:synckey]
      end
    end
    def pretty(ret)
      say "Adding:"
      ret[:toadd].each{|item| say " + #{item[:pp_type]}  #{fmtr(item)}"}
      say "Deleteing:"
      ret[:todel].each{|item| say " - #{item[:pp_type]}  #{fmtr(item)}"}
      say "Changing:"
      ret[:tomod].each{|item| say " M #{item[:pp_type]}  #{fmtr(item)}"}
    end

    @grouped = {:toadd=>[],:todel=>[],:tomod=>[]}
    def gmerge(ret, type)
      [:toadd, :todel, :tomod].each do |kind|
        ret[kind].each{|item| item[:pp_type] = type; @grouped[kind] << item}
      end
    end
    
    if options.endpoints then
      sol = MrMurano::Endpoint.new
      ret = sol.status($cfg['location.base'] + $cfg['location.endpoints'], options)
      gmerge(ret, ' EP ')
    end

    if options.modules then
      sol = MrMurano::Library.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.modules'], options)
      gmerge(ret, 'MOD ')
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.eventhandlers'], options)
      gmerge(ret, ' EH ')
    end

    if options.roles then
      sol = MrMurano::Role.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.roles'], options)
      gmerge(ret, 'ROLE')
    end

    if options.users then
      sol = MrMurano::User.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.users'], options)
      gmerge(ret, 'USER')
    end

    if options.files then
      sol = MrMurano::File.new
      ret = sol.status( $cfg['location.base'] + $cfg['location.files'], options)
      gmerge(ret, 'FILE')
    end

    pretty(@grouped)
  end
end
#  vim: set ai et sw=2 ts=2 :
