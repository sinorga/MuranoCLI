require 'pathname'
require 'fileutils'
require 'yaml'
require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/Config'


module MrMurano
  class ConfigMigrate
    include Verbose

    def import_secret
      solsecret = Pathname.new($cfg['location.base']) + '.Solutionfile.secret'
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

          $cfg.set('user.name', ss['email'])
          $cfg.set('application.id', ss['solution_id']) if ss.has_key? 'solution_id'
          $cfg.set('product.id', ss['product_id']) if ss.has_key? 'product_id'
        end
      end
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
