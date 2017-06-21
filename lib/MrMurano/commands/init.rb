require 'MrMurano/Account'
require 'MrMurano/Config-Migrate'
require 'MrMurano/Solution-Services'
require 'MrMurano/verbosing'
require 'erb'
require 'inflecto'
require 'rainbow'

MURANO_SIGN_UP_URL = "https://exosite.com/signup/"

command :init do |c|
  c.syntax = %{murano init}

  c.summary = %{The easy way to start a project}

  c.description = %{

The init command helps you create a new Murano project.
=======================================================

Example
-------

  Create a new project in a new directory:

    #{File.basename $PROGRAM_NAME} init my-new-app

Example
-------

  Create a project in the current directory, or rewrite an existing project:

    cd project/path
    #{File.basename $PROGRAM_NAME} init

Solutions
---------

The init command configures two new Solutions for your new Murano project:

  1. An Application

     The Application is what users see.

     Use the Application to control, monitor, and consume values from products.

  2. A Product

     A Product is something that captures data and reports it to the Application.

     A Product can be a physical device connected to the Internet. It can be
     a simulator running on your local network. It can be anything that
     triggers events or supplies input data to the Application.

How it Works
------------

You will be asked to log on to your Business account.

  - To create a new Murano business account, visit:

    #{MURANO_SIGN_UP_URL}

  - Once logged on, you can choose to store your logon token so you
    can skip this step when using Murano CLI.

After logon, name your Application, and then name your Product.

  - Please choose names that contain only lowercase letters and numbers.

    The names are used as variable names in scripts, and as domain names,
    so they cannot contain underscores, dashes, or other punctuation.

After creating the two Solutions, they will be linked.

  - Linking Solutions allows data and events to flow between the two.

    For example, a Product device generates data that will be consumed
    or processed by the Application.

The init command will pull down Product and Application services
that you can edit.

  - The services, or event handlers, let you control how data is
    processed and how your application behaves.

    Take a look at the new directories and files created in your
    Project after running init to see what services are available.

    There are many other resources that are not downloaded that
    you can also create and edit. Visit our docs site for more!

    http://docs.exosite.com/

}.strip
#  - You can link many Products and Applications.
#    You can also access and edit the same services using the web interface.
#    In fact, everything you can do in Murano CLI, you can also do via the web.

  c.option '--[no-]mkdirs', %{Create default directories}

  c.action do |args, options|
    options.default :force=>false, :mkdirs=>true
    acc = MrMurano::Account.new
    puts ''

    if $cfg['tool.dry']
      acc.error "Cannot run a --dry init."
      exit 2
    end

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

    newApp = false
    newPrd = false
    # 1. Get Business ID
    acquireBusinessId(options, acc)
    # 2. Get/Create Application ID
    aid, aname, newApp = acquireSolutionId(options, acc, :application, MrMurano::Application)
    # 3. Get/Create Product ID
    pid, pname, newPrd = acquireSolutionId(options, acc, :product, MrMurano::Product)

    # Automatically link solutions.
    if pid and aid then
      MrMurano::Verbose::whirly_start "Linking solutions..."
      sercfg = MrMurano::ServiceConfig.new
      ret = sercfg.create(pid, pname) do |request, http|
        response = http.request(request)
        MrMurano::Verbose::whirly_stop
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

    # If no ProjectFile, then write a ProjectFile.
    if not $project.usingProjectfile then
      tmpl = File.read(File.join(File.dirname(__FILE__), '..', 'template', 'projectFile.murano.erb'))
      tmpl = ERB.new(tmpl)
      res = tmpl.result($project.data_binding)
      prFile = $project['info.name'] + '.murano'
      say "Writing Project file to #{prFile}"
      puts ''
      File.open(prFile, 'w') {|io| io << res}
    end

    # Make the directory structure.
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

    # Murano creates a bunch of empty event handlers. Grab them now.
    # E.g., for the application, you'll see around 20 interface_<operationId>
    # event handlers, and one named device2_event.lua; for the product, you'll
    # see about 4 event handlers, including one named device2_event.lua (also:
    # timer_timer.lua, tsdb_exportJob.lua, and user_account.lua). The application
    # interface handlers are basic stubs, like
    #       --#EVENT interface <operationId>
    #       operation.solution_id = nil
    #       return Device2.<operationId>(operation)
    # The product handlers are different, and serve as example boilerplate
    # for user to fill in.
    # See:
    #   sphinx-api/src/views/interface/productService.swagger.json

    # Automatically pull down eventhandler stubs that Murano creates for new solutions.
    # Iterate over: MrMurano::EventHandlerSolnPrd, MrMurano::EventHandlerSolnApp.
    MrMurano::SyncRoot.each_filtered :eventhandlers => true do |name, type, klass, desc|
      MrMurano::Verbose::whirly_start "Populating #{desc}..."
      begin
        syncable = klass.new
      rescue MrMurano::ConfigError => err
        acc.error "Could not fetch status for #{desc}: #{err}"
        # MAYBE: exit?
      rescue StandardError => err
        raise
      else
        # Get list of changes. Leave :delete => true and :update => true so we
        # can tell if there are existing files, in which case skip the pull.
        stat = syncable.status({
          :asdown => true,
          :eventhandlers => true,
        })
        if stat[:todel].any? or stat[:tomod].any?
          MrMurano::Verbose::whirly_stop
          say "Skipping #{desc}: local files found"
          puts ''
        else
          stat[:toadd].each do |item|
            MrMurano::Verbose::whirly_msg "Pulling item #{item[:synckey]}"
            dest = syncable.tolocalpath(syncable.location, item)
            syncable.download(dest, item)
          end
        end
      end
      MrMurano::Verbose::whirly_stop
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
      MrMurano::Verbose::whirly_start "Verifying Business..."
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
      MrMurano::Verbose::whirly_stop
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

  def acquireSolutionId(options, acc, type, klass)
    sid = nil
    solname = nil
    isNewSoln = false

    raise "Unknown type(#{type})" unless MrMurano::Account::ALLOWED_TYPES.include? type

    # If user deleted solution via Web, .murano/config might be outdated.
    # Check sol'n exists.
    exists = false
    if not options.force and not $cfg["#{type}.id"].nil? then
      MrMurano::Verbose::whirly_start "Verifying #{type.capitalize}..."
      sol = klass.new
      ret = sol.info() do |request, http|
        response = http.request(request)
        if response.is_a? Net::HTTPSuccess then
          response = acc.workit_response(response)
          exists = true
          # [lb] expected this to be: sid = sol[:apiId]
          sid = response[:id]
          solname = response[:name]
        end
        response
      end
      MrMurano::Verbose::whirly_stop
      if exists
        say "Found #{type.capitalize} #{sol.pretty_desc}"
      else
        say "Could not find #{type.capitalize} " + $cfg["#{type}.id"] + " referenced in the config"
        puts ''
      end
    end

    unless exists
      solz = acc.solutions(type)
      if solz.count == 1 then
        sol = solz.first
        say "This business has one #{type.capitalize}. Using #{Rainbow(sol[:domain]).underline}"
        sid = sol[:apiId]
        solname = sol[:name]
        # Update the config file, both in memory and on drive.
        $cfg.set("#{type}.id", sid, :project)
      elsif solz.count == 0 then
        #say "You do not have any #{type}s. Let's create one."
        say "This business does not have any #{Inflecto.pluralize(type)}. Let's create one"

        asking = true
        while asking do
          solname = ask("\nPlease enter the #{type.capitalize} name: ")
          # LATER: Allow uppercase characters once services do.
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

