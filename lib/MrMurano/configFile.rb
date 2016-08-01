require 'pathname'
require 'inifile'
require 'pp'

module MrMurano
  class Config
    #
    #  internal    transient this-run-only things (also -c options)
    #  specified   from --configfile
    #  private     .mrmuranorc.private at project dir (for things you don't want to commit)
    #  project     .mrmuranorc at project dir
    #  user        .mrmuranorc at $HOME
    #  system      .mrmuranorc at /etc
    #  defaults    Internal hardcoded defaults
    #
    ConfigFile = Struct.new(:kind, :path, :data) do
      def load()
        return if kind == :internal
        return if kind == :defaults
        self[:path] = Pathname.new(path) unless path.kind_of? Pathname
        self[:data] = IniFile.new(:filename=>path.to_s) if self[:data].nil?
        self[:data].restore
      end

      def write()
        return if kind == :internal
        return if kind == :defaults
        self[:path] = Pathname.new(path) unless path.kind_of? Pathname
        self[:data] = IniFile.new(:filename=>path.to_s) if self[:data].nil?
        self[:data].save
      end
    end

    attr :paths

    CFG_LEVELS=%w{internal specified project user system defaults}.map{|i| i.to_sym}.freeze
    CFG_FILE_NAME = '.mrmuranorc'.freeze

    def initialize
      @paths = []
      @paths << ConfigFile.new(:internal, nil, IniFile.new())
      # :specified --configfile FILE goes here. (see load_specific)
      prjfile = findProjectFile()
      @paths << ConfigFile.new(:project, prjfile)
      @paths << ConfigFile.new(:user, Pathname.new(Dir.home) + CFG_FILE_NAME)
      @paths << ConfigFile.new(:system, Pathname.new('/etc') + CFG_FILE_NAME.sub(/^\./,''))
      @paths << ConfigFile.new(:defaults, nil, IniFile.new())


      set('tool.verbose', false, :defaults)
      set('tool.dry', false, :defaults)

      set('net.host', 'bizapi.hosted.exosite.io', :defaults)

      set('location.base', prjfile.dirname, :defaults)
      set('location.files', 'files', :defaults)
      set('location.endpoints', 'endpoints', :defaults)
      set('location.modules', 'modules', :defaults)
      set('location.eventhandlers', 'eventhandlers', :defaults)
      set('location.roles', 'roles.yaml', :defaults)
      set('location.users', 'users.yaml', :defaults)

      set('files.default_page', 'index.html', :defaults)

      set('eventhandler.skiplist', 'websocket webservice', :defaults)

      set('diff.cmd', 'diff -u', :defaults)
    end

    # Look at parent directories until HOME
    # Stop at first.
    def findProjectFile()
      result=nil
      home = Pathname.new(Dir.home)
      pwd = Pathname.new(Dir.pwd)
      return a if home == pwd
      pwd.dirname.ascend do |i| 
        break if i == home
        if (i + CFG_FILE_NAME).exist? then
          result = i + CFG_FILE_NAME
          break
        end
      end
      # if nothing found, assume it will live in pwd.
      result = Pathname.new(Dir.pwd) + CFG_FILE_NAME if result.nil?
      return result
    end

    def load()
      # - read/write config file in [Project, User, System] (all are optional)
      @paths.each { |cfg| cfg.load }
    end

    def load_specific(file)
      spc = ConfigFile.new(:specified, Pathname.new(file))
      @paths.insert(1, spc)
    end

    # key is <section>.<key>
    def get(key, scope=[:internal, :specified, :project, :user, :system, :defaults])
      scope = [scope] unless scope.kind_of? Array
      paths = @paths.select{|p| scope.include? p.kind}

      section, ikey = key.split('.')
      paths.each do |path|
        if path.data.has_section?(section) then
          sec = path.data[section]
          return sec if ikey.nil?
          if sec.has_key?(ikey) then
            return sec[ikey]
          end
        end
      end
      return nil
    end

    def dump()
      # have a fake, merge all into it, then dump it.
      base = IniFile.new()
      @paths.reverse.each do |ini|
        base.merge! ini.data
      end
      base.to_s
    end

    def set(key, value, scope=:project)
      section, ikey = key.split('.', 2)
      raise "Invalid key" if section.nil?
      if not section.nil? and ikey.nil? then
        # If key isn't dotted, then assume the tool section.
        ikey = section
        section = 'tool'
      end

      paths = @paths.select{|p| scope == p.kind}
      raise "Unknown scope" if paths.empty?
      cfg = paths.first
      data = cfg.data
      tomod = data[section]
      tomod[ikey] = value unless value.nil?
      tomod.delete(ikey) if value.nil?
      data[section] = tomod
      cfg.write
    end

    # key is <section>.<key>
    def [](key)
      get(key)
    end

    # For setting internal, this-run-only values
    def []=(key, value)
      set(key, value, :internal)
    end

  end
end

command :config do |c|
  c.syntax = %{mr config [options] <key> [<new value>]}
  c.summary = %{Get and set options}
  c.description = %{
  You can get, set, or query config options with this command.  All config options
  are in a 'section.key' format.  There is also a layer of scopes that the keys can
  be saved in.

  }

  c.example %{See what the current combined config is}, 'mr config --dump'

  c.option '--system', 'Use only the system config file'
  c.option '--user', 'Use only the config file in $HOME'
  c.option '--project', 'Use only the config file in the project'
  c.option '--specified', 'Use only the config file from the --config option.'
  c.option '--unset', 'Remove key from config file.'
  c.option '--dump', 'Dump the current combined view of the config'

  c.action do |args, options|

    if options.dump then
      say $cfg.dump()
    elsif args.count == 0 then
      say_error "Need a config key"
    elsif args.count == 1 and not options.unset then
      options.defaults :system=>false, :user=>false, :project=>false, :specified=>false

      # For read, if no scopes, than all. Otherwise just those specified
      scopes = []
      scopes << :system if options.system
      scopes << :user if options.user
      scopes << :project if options.project
      scopes << :specified if options.specified
      scopes = [:internal, :specified, :project, :user, :system, :defaults] if scopes.empty?

      say $cfg.get(args[0], scopes)
    else 

      options.defaults :system=>false, :user=>false, :project=>true, :specified=>false
      # For write, if scope is specified, only write to that scope.
      scope = :project
      scope = :system if options.system
      scope = :user if options.user
      scope = :project if options.project
      scope = :specified if options.specified

      args[1] = nil if options.unset
      $cfg.set(args[0], args[1], scope)
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
