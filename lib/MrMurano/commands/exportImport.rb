require 'pathname'
require 'json'
require 'yaml'
require 'fileutils'
require 'MrMurano/dir'
require 'MrMurano/Account'

command 'config export' do |c|
  c.syntax = %{mr config export}
  c.summary = %{Export data to Solutionfiles}
  c.description = %{Export data to Solutionfiles

  This will write to the Solutionfile.json and optionally the .Solutionfile.secret
  used by the exosite-cli tool.

  This also will merge all of the endpoints into a single 'routes.lua' file.
  }

  c.option '--force', "Overwrite existing files."
  c.option '--[no-]merge', "Merge endpoints into a single routes.lua file"
  c.option '--[no-]secret', %{Also write the .Solutionfile.secret}

  c.action do |args, options|
    options.default :merge => true, :secret => false

    solfile = Pathname.new($cfg['location.base']) + 'Solutionfile.json'
    solsecret = Pathname.new($cfg['location.base']) + '.Solutionfile.secret'

    if not options.force and (solfile.exist? or solsecret.exist?) then
      sol = MrMurano::Solution.new
      sol.error "Solutionfile.json or .Solutionfile.secret already exist."
      sol.error "Use --force to overwrite"
      exit 2
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

    MrMurano::Cors.new.locallist.each do |crs|
      solf[:cors] = crs.reject{|k,v| k==:id or k==:local_path}
    end

    solfile.open('w') do |io|
      io << JSON.pretty_generate(solf)
    end

    if options.secret then
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
end

command :migrate do |c|
  c.syntax = %{mr migrate}
  c.summary = %{Mirgrate a project}
  c.description = %{Migrate a project from Solutionfiles

  This imports from the Solutionfile.json and .Solutionfile.secret that are created
  by the exosite-cli tool.

  It also moves files into ideal locations and updates event handler headers.
  }

  c.action do |args, options|

    cm = MrMurano::ConfigMigrate.new(args, options)
    cm.load
    cm.migrate

    cm.import_secret

    say "Configuration items have been imported."
    #say "Use `mr syncdown` get get all endpoints, modules, and event handlers"
  end

end
alias_command 'config import', :migrate

#  vim: set ai et sw=2 ts=2 :
