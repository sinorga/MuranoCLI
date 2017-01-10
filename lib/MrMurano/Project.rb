require 'yaml'
require 'hash'
require 'vine'
require 'json-schema'
require 'MrMurano/Config'

module MrMurano
  ##
  # A project that is synced (or deployed) into Murano.
  class ProjectOld

    PROJECT_FILE_1_0_0 = "SolutionFile.json".freeze
    PROJECT_FILE_2_0_0 = "project.murano".freeze

    # Possible names for the project file.
    # In order of preference, least preferred to most preferred
    PROJECT_FILE_NAMES = [PROJECT_FILE_1_0_0, PROJECT_FILE_2_0_0]

    # The contents of this is explictily not just a nest of hashes and arrays.
    # To keep expectations in check, there is a set number of known keys.
    # This should also help by keeping the file format seperate from the internal
    # lookups.  Hopefully, this will avoid (or at least minimize) changes to the
    # file format affecting all kinds of code.
    PrjMeta = Struct.new(:name, :description, :authors, :version, :source, :dependencies)
    PrjFiles = Struct.new(:location, :searchFor, :ignoring, :default_page)
    PrjModules = Struct.new(:location, :searchFor, :ignoring)
    PrjEndpoints = Struct.new(:location, :searchFor, :ignoring)
    PrjEventHandlers = Struct.new(:location, :searchFor, :ignoring, :mapping)
    PrjCors = Struct.new(:origin, :methods, :headers, :credentials)

    def initialize()
      @prjFile = nil
      @data = {
        :meta => PrjMeta.new,
        :files => PrjFiles.new,
        :modules => PrjModules.new,
        :endpoints => PrjEndpoints.new,
        :eventhandlers => PrjEventHandlers.new,
        :cors => PrjCors.new,
      }
    end

    def get()
    end

    def load
      PROJECT_FILE_NAMES.each do |pn|
        if ($cfg['location.base'] + pn).exist? then
          @prjFile = ($cfg['location.base'] + pn)
        end
      end
      if @prjFile.nil? then
        error "No project file found!"
        return -1
      end

      data = nil
      @prjFile.open do |io|
        data = YAML.load(io)
      end
      # TODO: check for load errors

      data = Hash.transform_key_to_symbols(data)
      # get format version
      fmtvers = (data[:fmtvers] or '1.0.0')

      methodname = "load_#{fmtvers.gsub(/\./, '_')}".to_sym
      if respond_to? methodname then
        __send__(methodname, data)
      else
        error "Cannot load Project file of version #{fmtvers}"
      end
    end

    def ifset(src, skey, dest, dkey)
      dest[dkey] = src[skey] if src.has_key? skey
    end
    def load_1_0_0(data)
      ifset(data, :default_page, @data[:files], :default_page)
      ifset(data, :file_dir, @data[:files], :location)
    end
  end


  class Project
    def initialize
      @path = nil
      @schemaPath = nil
      @data = {}
      @key_alias = {}
    end

    def load_schema(path)
      return false unless path.exist?
      schema = nil
      path.open{|io| schema = YAML.load(io)}
      schema
    end

    def load
      # TODO scan up to $HOME looking for project file
      return false unless @path.exist?
      @path.open {|io| @data = YAML.load(io)}
    end

    def valid?
      schema = load_schema(@schemaPath)
      JSON::Validator.fully_validate(schema, @data)
    end

    ##
    # Get a piece of a Project config.
    # +key+:: The key for the item to get. Keys are dot seperated paths
    #
    # Some keys are virtual and this checks for those a dispatches as needed.
    def get(key)
      # if overriden by method, call it.
      meth = "get_#{key.gsub(/\./,'_')}".to_sym
      if respond_to? meth then
        __send__(meth)
      else
        # If key_alias exist, use that
        key = @key_alias[key] if @key_alias.has_key? key
        found = @data.access(key)
        return found unless found.nil?
        # if lookup is nil, try in cfg.
        $cfg[key]
      end
    end
  end

  class Project_V2 < Project
    def initialize
      @path = Pathname.new('project.murano')
      @schemaPath = Pathname.new(File.dirname(__FILE__)) + 'schema/sf-v2.0.0.yaml'

      @key_alias['files.searchFor'] = 'files.sources'
      @key_alias['modules.searchFor'] = 'modules.sources'
      @key_alias['endpoints.searchFor'] = 'endpoints.sources'
      @key_alias['files.searchFor'] = 'files.sources'
    end
  end

  class Project_V020 < Project
    def initialize
      @path = Pathname.new('SolutionFile.json')
      @schemaPath = Pathname.new(File.dirname(__FILE__)) + 'schema/sf-v0.2.0.yaml'

      @key_alias['files.location'] = 'file_dir'
      @key_alias['files.default_page'] = 'default_page'
    end

    # files.location -> file_dir || $cfg
    # files.searchFor -> $cfg
    # files.ignoring -> $cfg
    # files.default_page -> default_page || $cfg
    #
    # modules.location -> '.'
    # modules.searchFor : method
    # modules.ignoring -> $cfg
    #
    # endpoints.location
    # endpoints.searchFor
    # endpoints.ignoring -> $cfg
    #
    # eventhandlers.location : method
    # eventhandlers.searchFor
    # eventhandlers.ignoring -> $cfg
    # eventhandlers.events -> event_handler??? not sure yet.
    #
    # cors

    def get_modules_location
      # Should I add a data_alias? Or a post/pre load method to fill some data?
      # Either way, having a method for this is not preferred.
      "."
    end
    def get_modules_searchFor
      return [] unless @data.has_key? 'modules'
      return [] if @data['modules'].empty?
      @data['modules'].values
    end

    def get_endpoints_location
      '.'
    end
    def get_endpoints_searchFor
      [@data['custom_api']]
    end

    def get_eventhandlers_location
      '.'
    end
    def get_eventhandlers_searchFor
      return [] unless @data.has_key? 'event_handler'
      return [] if @data['event_handler'].empty?
      eventhandlers = @data['event_handler']
      eventhandlers.values.map{|e| e.values}.flatten
    end
  end

  class Project_V030 < Project
    def initialize
      @path = Pathname.new('SolutionFile.json')
      @schemaPath = Pathname.new(File.dirname(__FILE__)) + 'schema/sf-v0.3.0.yaml'

      @key_alias['files.location'] = 'assets'
      @key_alias['files.default_page'] = 'default_page'
    end
    def get_modules_location
      # Should I add a data_alias? Or a post/pre load method to fill some data?
      # Either way, having a method for this is not preferred.
      "."
    end
    def get_modules_searchFor
      return [] unless @data.has_key? 'modules'
      return [] if @data['modules'].empty?
      @data['modules'].values
    end

    def get_endpoints_location
      '.'
    end
    def get_endpoints_searchFor
      [@data['routes']]
    end

    def get_eventhandlers_location
      '.'
    end
    def get_eventhandlers_searchFor
      return [] unless @data.has_key? 'services'
      return [] if @data['services'].empty?
      eventhandlers = @data['services']
      eventhandlers.values.map{|e| e.values}.flatten
    end
  end

end
#  vim: set ai et sw=2 ts=2 :
