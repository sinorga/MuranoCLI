require 'pathname'
require 'fileutils'
require 'yaml'
require 'MrMurano/dir'
require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/Config'


module MrMurano
  class ConfigMigrate
    include Verbose

    def initialize()
      @soljson = Pathname.new($cfg['location.base']) + 'Solutionfile.json'
      @solsecret = Pathname.new($cfg['location.base']) + '.Solutionfile.secret'
      @soldata = {}

      @fuopts = {:noop=>$cfg['tool.dry'], :verbose=>$cfg['tool.verbose']}
    end

    def load()
      soljson = Pathname.new($cfg['location.base']) + 'Solutionfile.json'
      soljson.open do |io|
        @soldata = YAML.load(io)
      end
    end

    def import_secret
      if solsecret.exist? then
        # Is in JSON, which as a subset of YAML, so use YAML parser
        solsecret.open do |io|
          ss = YAML.load(io)

          pff = $cfg.file_at('passwords', :user)
          pwd = MrMurano::Passwords.new(pff)
          pwd.load
          ps = pwd.get($cfg['net.host'], ss['email'])
          if ps.nil? then
            pwd.set($cfg['net.host'], ss['email'], ss['password'])
            pwd.save
          elsif ps != ss['password'] then
            y = ask("A different password for this account already exists. Overwrite? N/y")
            if y =~ /^y/i then
              pwd.set($cfg['net.host'], ss['email'], ss['password'])
              pwd.save
            end
          else
            # already set, nothing to do.
          end

          $cfg.set('solution.id', ss['solution_id']) if ss.has_key? 'solution_id'
          $cfg.set('product.id', ss['product_id']) if ss.has_key? 'product_id'
        end
      end
    end

    def migrate
      # For each top level key in @soldata
      # - look for method named 'migrate_' + key
      # - If found; call it
      # - Else report skipping
      @soldata.each_pair do |key, data|
        if respond_to?("migrate_#{key}") then
          verbose "Migrating #{key}"
          send("migrate_#{key}", data)
        else
          warning "No migration for key #{key}"
        end
      end
    end

    def migrate_assests(data)
        $cfg.set('location.files', data)
    end

    def migrate_file_dir(data)
        $cfg.set('location.files', data)
    end

    def migrate_default_page(data)
        $cfg.set('files.default_page', data)
    end

    def migrate_custom_api(data)
      routes = data
      if routes == '' then
        verbose "No endpoints to import"
      elsif File.dirname(routes) == '.' then
        warning "Routes file #{File.basename(routes)} not in endpoints directory"
        warning "Moving it to #{$cfg['location.endpoints']}"
        FileUtils.mkpath($cfg['location.endpoints'], @fuopts)
        FileUtils.mv(routes, File.join($cfg['location.endpoints'], File.basename(routes)), @fuopts)
      else
        # Otherwise just use the location they already have
        routeDir = File.dirname(routes)
        verbose "For endpoints using #{routeDir}"
        if $cfg['location.endpoints'] != routeDir then
          $cfg.set('location.endpoints', routeDir)
        end
      end
    end
    alias_method :migrate_routes, :migrate_custom_api

    def migrate_cors(data)
      verbose "Exporting CORS to #{$cfg['location.cors']}"
      File.open($cfg['location.cors'], 'w') do |cio|
        cio << sf['cors'].to_yaml
      end
    end

    def migrate_modules(data)
      update_or_stop(modules.values, 'location.modules', 'modules')
    end

    def migrate_event_handler(data)
      evd = data.values.map{|e| e.values}.flatten
      update_or_stop(evd, 'location.eventhandlers', 'eventhandlers')

      # add header to each eventhandler
      data.each do |service, events|
        events.each do |event, path|
          # open path, if no header, add it
          data = IO.readlines(path)
          dheader = "--#EVENT #{service} #{event}"
          aheader = (data.first or "").chomp
          if aheader != dheader then
            verbose "Adding event header to #{path}"
            data.insert(0, dheader)
            File.open(path, 'w'){|eio| eio.puts(data)} unless $cfg['tool.dry']
          end
        end
      end
    end
    alias_method :mirgrate_services, :migrate_event_handler

    # TODO: change this to take advantage of searchFor
    #
    # - Find common_root; set cfgkey to that.
    #   This could be '.'
    # - From all, remove common_root.
    # - Compare to locallist().
    #   - For items missing, add to searchFor
    #   - For items added, add to ignoring
    #
    def update_or_stop(paths, cfgkey, what)
      crd = Dir.common_root(paths)
      debug "crd => #{crd}"
      if crd.empty? then
        error "#{what.capitalize} in multiple directories! #{crd.join(', ')}"
        error "Please move them manually into #{$cfg[cfgkey]}"
        exit(1)
      else
        maxd = Dir.max_depth(paths) - crd.count
        if maxd > 2 then
          error "Some #{what} are in directories too deep."
          error "Please move them manually to #{$cfg[cfgkey]}"
          exit(1)
        else
          crd = File.join(crd)
          verbose "For #{what} using #{crd}"
          if $cfg[cfgkey] != crd then
            $cfg.set(cfgkey, crd)
          end
        end
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
