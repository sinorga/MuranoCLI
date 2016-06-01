require 'rubygems'
require 'pathname'
require 'inifile'
require 'pp'

module MrMurano
  class Config
    ConfigFile = Struct.new(:kind, :path, :data) do
      def load()
        return if kind == :internal
        self[:path] = Pathname.new(path) unless path.kind_of? Pathname
        self[:data] = IniFile.new(:filename=>path.to_s) if self[:data].nil?
        self[:data].restore
      end

      def write()
        return if kind == :internal
        self[:path] = Pathname.new(path) unless path.kind_of? Pathname
        self[:data] = IniFile.new(:filename=>path.to_s) if self[:data].nil?
        self[:data].save
      end
    end

    attr :paths

    CFG_FILE_NAME = '.mrmuranorc'.freeze

    def initialize
      @paths = []
      @paths << ConfigFile.new(:internal, nil, IniFile.new())
      # TODO --config FILE goes here.
      @paths << ConfigFile.new(:project, findProjectFile())
      @paths << ConfigFile.new(:user, Pathname.new(Dir.home) + CFG_FILE_NAME)
      @paths << ConfigFile.new(:system, Pathname.new('/etc') + CFG_FILE_NAME.sub(/^\./,'')))
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

    # key is <section>.<key>
    def get(key, scope=[:internal, :specified, :project, :user, :system])
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

    def set(key, value, scope=:project)
      section, ikey = key.split('.')
      raise "Missing section" if section.nil?
      raise "Missing key" if ikey.nil?

      paths = @paths.select{|p| scope == p.kind}
      raise "Unknown scope" if paths.empty?
      data = paths.first.data
      tomod = data[section]
      tomod[ikey] = value
      data[section] = tomod
      data.save
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
  c.summary = %{}
  c.option '--system', 'Use only the system config file'
  c.option '--user', 'Use only the config file in $HOME'
  c.option '--project', 'Use only the config file in the project'
  c.option '--specified', 'Use only the config file from the --config option.'


  c.action do |args, options|

    # Get and Set.
    if args.count == 1 then
      options.defaults :system=>false, :user=>false, :project=>false, :specified=>false

      # For read, if no scopes, than all. Otherwise just those specified
      scopes = []
      scopes << :system if options.system
      scopes << :user if options.user
      scopes << :project if options.project
      scopes << :specified if options.specified
      scopes = [:internal, :specified, :project, :user, :system] if scopes.empty?

      say $cfg.get(args[0], scopes)
    else

      options.defaults :system=>false, :user=>false, :project=>true, :specified=>false
      # For write, if scope is specified, only write to that scope.
      scope = :project
      scope = :system if options.system
      scope = :user if options.user
      scope = :project if options.project
      scope = :specified if options.specified

      $cfg.set(args[0], args[1], scope)
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
