require 'MrMurano/Account'
require 'MrMurano/Config-Migrate'
require 'erb'


command :init do |c|
  c.syntax = %{murano init}
  c.summary = %{The easy way to start a project}
  c.description = %{}

  c.option '--force', %{Override existing business, or project ids}
  c.option '--[no-]mkdirs', %{Create default directories}

  c.action do |args, options|
    options.default :force=>false, :mkdirs=>true
    acc = MrMurano::Account.new
    puts ''

    if Pathname.new(Dir.pwd).realpath == Pathname.new(Dir.home).realpath then
      acc.error "Cannot init a project in your HOME directory."
      exit 2
    end

    say "Found project base directory at #{$cfg['location.base'].to_s}"
    puts ''

    # Try to import a .Solutionfile.secret
    MrMurano::ConfigMigrate.new.import_secret

    # If they have never logged in, then asking for the business.id will also ask
    # for their username and password.
    say "Using account #{$cfg['user.name']}"
    say ''

    # 1. Get business id
    if not options.force and not $cfg['business.id'].nil? then
      say "Using Business ID already set to #{$cfg['business.id']}"
    else
      bizz = acc.businesses
      if bizz.count == 1 then
        bizid = bizz.first
        say "You are only part of one business; using #{bizid[:name]}"
        $cfg.set('businesses.id', bizid[:bizid], :project)

      elsif bizz.count == 0 then
        acc.warning "You don't have any businesses; Log into the webUI and create one."
        exit 3
      else
        choose do |menu|
          menu.prompt = "Select which Business to use:"
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

    # 2. Get Project id
    if not options.force and not $cfg['project.id'].nil? then
      say "Using Project ID already set to #{$cfg['project.id']}"
    else
      solz = acc.products
      if solz.count == 1 then
        sol = solz.first
        say "You only have one project; using #{sol[:domain]}"
        $cfg.set('project.id', sol[:apiId], :project)

      elsif solz.count == 0 then
        say "You don't have any projects; lets create one"
        solname = ask("Project Name? ")
        ret = acc.new_product(solname)
        if ret.nil? then
          acc.error "Create Project failed"
          exit 5
        end
        if not ret.kind_of?(Hash) and not ret.empty? then
          acc.error "Create Project failed: #{ret.to_s}"
          exit 2
        end

        # create doesn't return anything, so we need to go look for it.
        ret = acc.products.select{|i| i[:domain] =~ /#{solname}\./}
        sid = ret.first[:apiId]
        if sid.nil? or sid.empty? then
          acc.error "Project didn't find an apiId!!!!  #{ret}"
          exit 3
        end
        $cfg.set('project.id', sid, :project)

      else
        choose do |menu|
          menu.prompt = "Select which Project to use:"
          menu.flow = :columns_across
          solz.sort{|a,b| a[:domain]<=>b[:domain]}.each do |s|
            menu.choice(s[:domain].sub(/\..*$/,'')) do
              $cfg.set('project.id', s[:apiId], :project)
            end
          end
        end
      end
    end
    puts '' # blank line

    say "Ok, In business ID: #{$cfg['business.id']} using Project ID: #{$cfg['project.id']}"

    # If no ProjectFile, then write a ProjectFile
    if not $project.usingProjectfile then
      tmpl = File.read(File.join(File.dirname(__FILE__),'..','template','projectFile.murano.erb'))
      tmpl = ERB.new(tmpl)
      res = tmpl.result($project.data_binding)
      prFile = $project['info.name'] + '.murano'
      say "Writing an initial Project file: #{prFile}"
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
      say "Default directories created"
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
