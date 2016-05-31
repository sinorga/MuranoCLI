require 'pathname'
require 'inifile'
require 'pp'

class Config
	ConfigFile = Struct.new(:kind, :path, :data) do
		def load()
			return if kind == :internal
			self[:path] = Pathname.new(path) unless path.kind_of? Pathname
      self[:data] = IniFile.new(:filename=>path.path) if self[:data].nil?
      self[:data].restore
		end

		def write()
			return if kind == :internal
			self[:path] = Pathname.new(path) unless path.kind_of? Pathname
      self[:data] = IniFile.new(:filename=>path.path) if self[:data].nil?
      self[:data].save
		end
	end

  attr :paths

  def initialize
    @paths = []
    @paths << ConfigFile.new(:project, findProjectFile())
    @paths << ConfigFile.new(:user, Pathname.new(Dir.home) + '.mrmuranorc')
    @paths << ConfigFile.new(:system, Pathname.new('/etc/mrmuranorc')) # FIXME system should be located in the INSTALL location, not /etc.
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
      if (i + '.mtmuranorc').exist? then
        result = i + '.mtmuranorc'
        break
      end
    end
    return result
  end

  def load()
    # - read/write config file in [Project, User, System] (all are optional)
    @paths.each { |cfg| cfg.load }
  end

  # key is <section>.<key>
  def [](key)
    section, ikey = key.split('.')
    # TODO search each cfg file in turn to find value
  end

end


command :config do |c|
  c.syntax = %{mr config }
  c.summary = %{}
  c.option '--user', 'Use the config file in $HOME'
  c.option '--system', 'Use the config file in ...'
  c.option '--project', 'Use the config file in ...'
  c.option '--specified', 'Use the config file from the --config option.'

  c.option 

  c.action do |args.options|
    
  end

end

#  vim: set ai et sw=2 ts=2 :
