require 'pathname'
require 'json'
require 'fileutils'

command 'config export' do |c|
  c.syntax = %{mr config export}
  c.summary = %{Export data to Solutionfiles}
  c.description = %{Export data to Solutionfiles

  This will write to the Solutionfile.json and .Solutionfile.secret used by the
  exosite-cli tool.

  This also will merge all of the endpoints into a single 'routes.lua' file.
  }

  c.option '--force', "Overwrite existing files."
  c.option '--[no-]merge', "Merge endpoints into a single routes.lua file"

  c.action do |args, options|
    options.defaults :merge => true

    solfile = Pathname.new($cfg['location.base'] + 'Solutionfile.json')
    solsecret = Pathname.new($cfg['location.base'] + '.Solutionfile.secret')

    if not options.force and (solfile.exist? or solsecret.exist?) then
      say_error "Solutionfile.json or .Solutionfile.secret already exist."
      say "Use --force to overwrite"
    end

    solf = {
      :assets => $cfg['location.files'],
      :default_page => $cfg['files.default_page'],
      :services => {},
      :modules => {}
    }

    if options.merge then
      epf = 'routes.lua'
      File.open(epf, 'w') do |dst|
        MrMurano::Endpoint.new.locallist.each do |ed|
          ed[:local_path].open do |fin|
            FileUtils.copy_stream(fin, dst)
          end
          dst << "\n\n"
        end
      end
      solf[:routes] = epf
    end

    dpwd = Pathname.new(Dir.pwd)
    MrMurano::EventHandler.new.locallist.each do |ev|
      rp = ev[:local_path].relative_path_from(dpwd).to_s
      if solf[:services].has_key?(ev[:service]) then
        solf[:services][ev[:service]][ev[:event]] = rp
      else
        solf[:services][ev[:service]] = {ev[:event] => rp}
      end
    end

    MrMurano::Library.new.locallist.each do |lb|
      solf[:modules][lb[:name]] = lb[:local_path].relative_path_from(dpwd).to_s
    end

    solfile.open('w') do |io|
      io << JSON.pretty_generate(solf)
    end

    solsecret.open('w') do |io|
        pff = $cfg.file_at('passwords', :user)
        pwd = MrMurano::Passwords.new(pff)
        pwd.load
        ps = pwd.get($cfg['net.host'], $cfg['user.name'])
      io << {
        :email => $cfg['user.name'],
        :password => ps,
        :solution_id => $cfg['solution.id'],
        :product_id => $cfg['product.id']
      }.to_json
    end

  end
end

command 'config import' do |c|
  c.syntax = %{mr config import}
  c.summary = %{Import data from Solutionfiles}
  c.description = %{Import data from Solutionfiles

  This imports from the Solutionfile.json and .Solutionfile.secret that are created
  by the exosite-cli tool.
  }

  c.action do |args, options|
    solfile = ($cfg['location.base'] + 'Solutionfile.json')
    solsecret = ($cfg['location.base'] + '.Solutionfile.secret')

    if solfile.exist? then
      # Is in JSON, which as a subset of YAML, so use YAML parser
      solfile.open do |io|
        sf = YAML.load(io)
        $cfg.set('location.files', sf['assets']) if sf.has_key? 'assets'
        $cfg.set('location.files', sf['file_dir']) if sf.has_key? 'file_dir'
        $cfg.set('files.default_page', sf['default_page']) if sf.has_key? 'default_page'
      end
    end

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

    say "Configuration items have been imported."
    say "Use `mr syncdown` get get all endpoints, modules, and event handlers"
  end

end

#  vim: set ai et sw=2 ts=2 :
