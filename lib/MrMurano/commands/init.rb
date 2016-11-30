require 'MrMurano/Account'


command :init do |c|
  c.syntax = %{mr init}
  c.summary = %{The easy way to start a project}
  c.description = %{}

  c.option '--force', %{Override existing business, solution, or product ids}
  c.option '--[no-]mkdirs', %{Create default directories}

  c.action do |args, options|
    options.default :force=>false, :mkdirs=>true

    if not options.force and ($cfg['location.base'] + 'Solutionfile.json').exist? then
      y=ask("A Solutionfile.json exists, Do you want exit and run `mr config import` instead? [yN]")
      exit 0 unless y =~ /^n/i
    end


    # If they have never logged in, then asking for the business.id will also ask
    # for their username and password.
    acc = MrMurano::Account.new


    # 1. Get business id
    if not options.force and not $cfg['business.id'].nil? then
      say "Using Business ID already set to #{$cfg['business.id']}"
    else
      bizz = acc.businesses
      if bizz.count == 1 then
        bizid = bizz.first
        say "You are only part of one business; using #{bizid[:name]}"
        $cfg.set('businesses.id', bizid[:bizid], :project)

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

    # 2. Get Solution id
    if not options.force and not $cfg['solution.id'].nil? then
      say "Using Solution ID already set to #{$cfg['solution.id']}"
    else
      solz = acc.solutions
      if solz.count == 1 then
        sol = solz.first
        say "You only have one solution; using #{sol[:domain]}"
        $cfg.set('solution.id', sol[:apiId], :project)
      else
        choose do |menu|
          menu.prompt = "Select which Solution to use:"
          menu.flow = :columns_across
          solz.sort{|a,b| a[:domain]<=>b[:domain]}.each do |s|
            menu.choice(s[:domain].sub(/\..*$/,'')) do
              $cfg.set('solution.id', s[:apiId], :project)
            end
          end
        end
      end
    end
    puts '' # blank line

    # 3. Get Product id
    if not options.force and not $cfg['product.id'].nil? then
      say "Using Product ID already set to #{$cfg['product.id']}"
    else
      podz = acc.products
      if podz.count == 1 then
        prd = podz.first
        say "You only have one product; using #{prd[:label]}"
        $cfg.set('product.id', prd[:modelId], :project)
      else
        choose do |menu|
          menu.prompt = "Select which Product to use:"
          menu.flow = :columns_across
          podz.sort{|a,b| a[:label]<=>b[:label]}.each do |p|
            menu.choice(p[:label]) do
              $cfg.set('product.id', p[:modelId], :project)
            end
          end
        end
      end
    end


    puts ''
    say "Ok, In business ID: #{$cfg['business.id']} using Solution ID: #{$cfg['solution.id']} with Product ID: #{$cfg['product.id']}"

    if options.mkdirs then
      %w{
        location.files
        location.endpoints
        location.modules
        location.eventhandlers
        location.specs
      }.each do |cfgi|
        path = $cfg[cfgi]
        path = Pathname.new(path) unless path.kind_of? Pathname
        path.mkpath unless path.exist?
      end
      say "Default directories created"
    end

  end
end

#  vim: set ai et sw=2 ts=2 :