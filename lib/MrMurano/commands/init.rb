require 'MrMurano/Account'
require 'MrMurano/Config-Migrate'
require 'erb'
require 'inflecto'
require 'rainbow'

MURANO_SIGN_UP_URL = "https://exosite.com/signup/"

command :init do |c|
  c.syntax = %{murano init}
  c.summary = %{The easy way to start a project}
  c.description = %{}

  c.option '--force', %{Override existing business, product, or application ids}
  c.option '--[no-]mkdirs', %{Create default directories}

  c.action do |args, options|
    options.default :force=>false, :mkdirs=>true
    acc = MrMurano::Account.new
    puts ''

    if Pathname.new(Dir.pwd).realpath == Pathname.new(Dir.home).realpath then
      acc.error "Cannot init a project in your HOME directory."
      exit 2
    end

    say "Creating project at #{Rainbow($cfg['location.base'].to_s).underline}"
    puts ''

    # Try to import a .Solutionfile.secret
    MrMurano::ConfigMigrate.new.import_secret

    # If they have never logged in, then asking for the business.id will also ask
    # for their username and password.
    say "Found User #{Rainbow($cfg['user.name']).underline}"
    puts '' # `say ''` doesn't actually print anything

    newPrd = false
    newApp = false
    # 1. Get Business ID
    acquireBusinessId(options, acc)
    # 2. Get Product ID
    pid, pname, newPrd = acquireSolutionId(options, acc, :product)
    # 3. Get Application ID
    aid, aname, newApp = acquireSolutionId(options, acc, :application)

    # Automatically link solutions.
    if pid and aid then
      sercfg = MrMurano::ServiceConfig.new
      ret = sercfg.create(pid, pname) do |request, http|
        response = http.request(request)
        if response.is_a? Net::HTTPSuccess then
          say "Linked #{pname} and #{aname}"
        elsif response.is_a? Net::HTTPConflict
          say "Verified #{pname} and #{aname} are linked"
        else
          acc.error "Unable to link solutions because #{Rainbow(response.message).underline}"
        end
      end
      puts ''
    end

    # If no ProjectFile, then write a ProjectFile
    if not $project.usingProjectfile then
      tmpl = File.read(File.join(File.dirname(__FILE__),'..','template','projectFile.murano.erb'))
      tmpl = ERB.new(tmpl)
      res = tmpl.result($project.data_binding)
      prFile = $project['info.name'] + '.murano'
      say "Writing Project file to #{prFile}"
      puts ''
      File.open(prFile, 'w') {|io| io << res}
    end

    if options.mkdirs then
      base = $cfg['location.base']
      base = Pathname.new(base) unless base.kind_of? Pathname
      %w{
        location.files
        location.endpoints
        location.modules
        location.eventhandlers
        location.resources
      }.each do |cfgi|
        path = $cfg[cfgi]
        path = Pathname.new(path) unless path.kind_of? Pathname
        path = base + path
        unless path.exist? then
          path = path.dirname unless path.extname.empty?
          path.mkpath
        end
      end
      say 'Created default directories'
      puts ''
    end

    say 'Success!'
    puts ''
    id_postfix = ' ID'
    important_ids = %w{business product application}.freeze
    importantest_width = important_ids.map do |id_name|
      cfg_key = id_name + '.id'
      $cfg[cfg_key].length + id_postfix.length
    end.max # Ruby is so weird! Max the map. [lb]
    important_ids.each do |id_name|
      # cfg_key is, e.g., 'business.id', 'product.id', 'application.id'
      cfg_key = id_name + '.id'
      unless $cfg[cfg_key].nil?
        #say "#{id_name.capitalize} ID: #{highlightID($cfg[cfg_key])}"
        # Right-aligned:
        tmpl = "%%%ds: %%s" % importantest_width
        # Left-aligned:
        #tmpl = "%%-%ds: %%s" % importantest_width
        say tmpl % [id_name.capitalize + id_postfix, highlightID($cfg[cfg_key]),]
      end
    end
    puts ''

  end

  def highlightID(id)
    Rainbow(id).aliceblue.bright.underline
  end

  def acquireBusinessId(options, acc)
    exists = false
    if not options.force and not $cfg['business.id'].nil? then
      # Verify that the business exists.
      biz = acc.overview do |request, http|
        response = http.request(request)
        if response.is_a? Net::HTTPSuccess then
          exists = true
          response = acc.workit_response(response)
        end
        # Ruby is so weird. In the do block, we can return a value
        # to the caller (which called yield). But don't use the
        # return keyword, lest we also leave our enclosing function
        # (acquireBusinessId); just leave the value as the last line.
        #  [2017-06-14: [lb] still learning Ruby nuances.]
        response
      end
      if exists
        say "Found Business #{Rainbow(biz[:name]).underline} <#{$cfg['business.id']}>"
      else
        say "Could not find Business #{$cfg['business.id']} referenced in the config"
        puts ''
      end
    end

    unless exists
      bizz = acc.businesses
      if bizz.count == 1 then
        bizid = bizz.first
        say "This user has one business. Using #{Rainbow(bizid[:name]).underline}"
        $cfg.set('businesses.id', bizid[:bizid], :project)
      elsif bizz.count == 0 then
        acc.warning "This user has not created any businesses."
        say "Please log on to exosite.com to create a free account. Visit:"
        say "  #{MURANO_SIGN_UP_URL}"
        exit 3
      else
        choose do |menu|
          menu.prompt = "Please select the Business to use:"
          menu.flow = :columns_across
          bizz.sort{|a,b| a[:name]<=>b[:name]}.each do |b|
            menu.choice(b[:name]) do
              $cfg.set('business.id', b[:bizid], :project)
            end
          end
        end
      end
    end
    puts '' # blank line
  end

  def acquireSolutionId(options, acc, type)
    isNewSoln = false
    raise "Unknown type(#{type})" unless MrMurano::Account::ALLOWED_TYPES.include? type
    if not options.force and not $cfg["#{type}.id"].nil? then
      # If user deleted a solution via Web or even using MurCLI,
      # the .murano/config is not updated, so check sol'n exists.
      say "#{type.capitalize} ID already set to " + $cfg["#{type}.id"]
    else
      sid = nil
      solname = nil
      solz = acc.solutions(type)
      if solz.count == 1 then
        sol = solz.first
        say "This business has one #{type.capitalize}. Using #{Rainbow(sol[:domain]).underline}"
        sid = sol[:apiId]
        $cfg.set("#{type}.id", sid, :project)
        solname = sol[:name]
      elsif solz.count == 0 then
        #say "You do not have any #{type}s. Let's create one."
        say "This business does not have any #{Inflecto.pluralize(type)}. Let's create one"

        asking = true
        while asking do
          solname = ask("\nPlease enter the #{type.capitalize} name: ")
          # LATER: Allow uppercase characters once pegasus_registry does.
          unless solname.match(MrMurano::Account::SOLN_NAME_REGEX)
            say MrMurano::Account::SOLN_NAME_HELP
          else
            break
          end
        end

        ret = acc.new_solution(solname, type)
        if ret.nil? then
          acc.error "Create #{type.capitalize} failed"
          exit 5
        end
        if not ret.kind_of?(Hash) and not ret.empty? then
          acc.error "Create #{type.capitalize} failed: #{ret.to_s}"
          exit 2
        end
        isNewSoln = true

        # create doesn't return anything, so we need to go look for it.
        ret = acc.solutions(type=type, invalidate=true).select do |i|
          i[:name] == solname or i[:domain] =~ /#{solname}\./i
        end
        sid = (ret.first or {})[:apiId]
        if sid.nil? or sid.empty? then
          acc.error "Solution didn't find an apiId!!!! #{name} -> #{ret}"
          exit 3
        end
        $cfg.set("#{type}.id", sid, :project)

      else
        choose do |menu|
          menu.prompt = "Select which #{type.capitalize} to use:"
          menu.flow = :columns_across
          # NOTE: There are 2 human friendly identifiers, :name and :domain.
          solz.sort{|a,b| a[:domain]<=>b[:domain]}.each do |sol|
            menu.choice(s[:domain].sub(/\..*$/, '')) do
              sid = sol[:apiId]
              $cfg.set("#{type}.id", sid, :project)
              solname = sol[:name]
            end
          end
        end
      end
    end
    puts '' # blank line

    return sid, solname, isNewSoln
  end

end

#  vim: set ai et sw=2 ts=2 :
