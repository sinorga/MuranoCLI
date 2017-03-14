require 'yaml'
require 'json-schema'
require 'pathname'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require 'MrMurano/hash'

module MrMurano
  ##
  # A Project File that describes details about a project that is synced into
  # Murano
  class ProjectFile
    include Verbose

    # Methods that are common to various internal structs.
    module PrjStructCommonMethods
      ## Load data from Hash into self
      #
      # Also makes sure that :include and :exclude are arrays.
      #
      # @param obj [Hash] Data to load in
      def load(obj)
        self.members.reject{|key| [:legacy].include? key}.each do |key|
          self[key] = obj[key] if obj.has_key? key
        end
        self.members.select{|k| [:include, :exclude].include? k}.each do |key|
          self[key] = [self[key]] unless self[key].kind_of? Array
        end
      end

      ## Returns a sparse hash of the data in self
      # @return [Hash] Just the non-nil members of this
      def save
        ret={}
        self.members.reject{|key| [:legacy].include? key}.each do |key|
          ret[key] = self[key] unless self[key].nil?
        end
        ret
      end
    end

    # The contents of this is explictily not just a nest of hashes and arrays.
    # To keep expectations in check, there is a set number of known keys.
    # This should also help by keeping the file format seperate from the internal
    # lookups.  Hopefully, this will avoid (or at least minimize) changes to the
    # file format affecting all kinds of code.
    PrjMeta = Struct.new(:name, :summary, :description, :authors, :version, :source, :dependencies) do
      include PrjStructCommonMethods
    end

    PrjFiles = Struct.new(:location, :include, :exclude, :default_page) do
      include PrjStructCommonMethods
    end

    PrjModules = Struct.new(:location, :include, :exclude) do
      include PrjStructCommonMethods
    end

    PrjEndpoints = Struct.new(:location, :include, :exclude, :cors) do
      include PrjStructCommonMethods
    end

    PrjEventHandlers = Struct.new(:location, :include, :exclude, :legacy) do
      include PrjStructCommonMethods
    end

    PrjResources = Struct.new(:location, :include, :exclude) do
      include PrjStructCommonMethods
    end

    PrfFile = Struct.new(:info, :assets, :modules, :routes, :services, :resources) do
      ## Returns a sparse hash of the data in self
      # @return [Hash] Just the non-empty members of this
      def save
        ret={}
        self.members.each do |key|
          value = self[key].save
          ret[key] = value unless value.empty?
        end
        ret
      end
      def get_binding
        binding()
      end
    end

    def initialize()
      @prjFile = nil
      tname = $cfg['location.base'].basename.to_s.gsub(/[^A-Za-z0-9]/, '')
      @data = PrfFile.new(
        PrjMeta.new(
          tname,
          "One line summary of #{tname}",
          "In depth description of #{tname}\n\nWith lots of details.",
          [$cfg['user.name']],
          "1.0.0",
          nil,
          nil
        ),
        PrjFiles.new,
        PrjModules.new,
        PrjEndpoints.new,
        PrjEventHandlers.new,
        PrjResources.new,
      )
    end

    # Get the current Project file
    # @return [Pathname] PAth to current project file.
    def project_file
      @prjFile
    end
    # Get a binding to the data for building the example ProjectFile
    def data_binding
      @data.get_binding
    end

    # Get a value for a key.
    # Keys are 'section.key'
    def get(key)
      raise "Empty key" if key.empty?
      section, ikey = key.split('.')
      raise "Missing dot" if ikey.nil? and section == key
      raise "Missing key" if ikey.nil? and section != key
      ret = @data[section.to_sym][ikey.to_sym]
      return default_value_for(key) if ret.nil?
      return ret
    end
    alias [] get

    # Get the default value for a key.
    #
    # Keys are 'section.key'
    #
    # All of these are currently stored in $cfg, but under different names.
    def default_value_for(key)
      keymap = {
        'assets.location' => 'location.files',
        'assets.include' => 'files.searchFor',
        'assets.exclude' => 'files.ignoring',
        'assets.default_page' => 'files.default_page',
        'modules.location' => 'location.modules',
        'modules.include' => 'modules.searchFor',
        'modules.exclude' => 'modules.ignoring',
        'routes.location' => 'location.endpoints',
        'routes.include' => 'endpoints.searchFor',
        'routes.exclude' => 'endpoints.ignoring',
        'routes.cors' => 'location.cors',
        'services.location' => 'location.eventhandlers',
        'services.include' => 'eventhandler.searchFor',
        'services.exclude' => 'eventhandler.ignoring',
        'resources.location' => 'location.resources',
        'resources.include' => 'product.spec',
        'resources.exclude' => 'product.ignoring',
      }.freeze
      needSplit = %r{.*\.(searchFor|ignoring)$}.freeze
      return nil unless keymap.has_key? key
      # *.{include,exclude} want arrays returned. But what they map to is
      # strings.
      cfg_key = keymap[key]
      ret = ($cfg[cfg_key] or '')
      ret = ret.split() if cfg_key =~ needSplit
      ret
    end

    # Set a value for a key.
    # Keys are 'section.key'
    def set(key, value)
      section, ikey = key.split('.')
      begin
        sec = @data[section.to_sym]
        sec[ikey.to_sym] = value
      rescue NameError => e
        debug ">>=>> #{e}"
      end
    end
    alias []= set

    ## Save the Project File.
    #
    # This ALWAYS saves in the latest format only.
    def save(ios=$stdout)
      dt = @data.save
      dt = Hash.transform_keys_to_strings(dt).to_yaml
      if ios.nil?
        dt
      else
        ios.write dt
      end
    end

    ##
    # Load the project file in the project directory.
    def load
      possible = Dir[
        ($cfg['location.base'] + '*.murano').to_s,
        ($cfg['location.base'] + 'Solutionfile.json').to_s,
      ]
      debug "Possible Project files: #{possible}"
      return 0 if possible.empty? # this is ok.

      warning "Multiple possible Project files! #{possible}" if possible.count > 1
      @prjFile = Pathname.new(possible.first)

      data = nil
      begin
        data = YAML.load_file(@prjFile.to_s)
      rescue Exception => e
        error "Load error; #{e}"
        pp e
        return -3
      end
      if data.nil? then
        error "Failed to load #{@prjFile}"
        return -2
      end
      unless data.kind_of?(Hash) then
        error "Bad format in #{@prjFile}"
        return -4
      end

      data = Hash.transform_keys_to_symbols(data)

      # get format version; little different for older format.
      if @prjFile.basename.to_s == "Solutionfile.json" then
        fmtvers = (data[:version] or '0.2.0')
      else
        fmtvers = (data[:formatversion] or '1.0.0')
      end

      methodname = "load_#{fmtvers.gsub(/\./, '_')}".to_sym
      debug "Will try to #{methodname}"
      if respond_to? methodname then
        errorlist = __send__(methodname, data)
        unless errorlist.empty? then
          error %{Project file #{@prjFile} not valid.}
          errorlist.each{|er| error er}
          return -5
        end
      else
        error "Cannot load Project file of version #{fmtvers}"
      end
    end

    # Only set destination if source has key
    # @param src [Hash,Struct] Source of value to copy
    # @param skey [String,Symbol] Key in source to check and read
    # @param dest [Hash,Struct] Destination to save value in
    # @param dkey [String,Symbol] Key in destination to save to
    def ifset(src, skey, dest, dkey)
      dest[dkey] = src[skey] if src.has_key? skey
    end

    # Load data in the 1.0.0 format.
    # @param data [Hash] the data to load
    # @return [Array] An array of validation errors in the data
    def load_1_0_0(data)
      schemaPath = Pathname.new(::File.dirname(__FILE__)) + 'schema/pf-v1.0.0.yaml'
      schema = YAML.load_file(schemaPath.to_s)
      v = JSON::Validator.fully_validate(schema, data)
      return v unless v.empty?

      @data.each_pair do |key, str|
        str.load(data[key]) if data.has_key? key
      end

      []
    end
    alias load_1_0 load_1_0_0
    alias load_1 load_1_0_0

    # Load data in the 0.2.0 format.
    # @param data [Hash] the data to load
    # @return [Array] An array of validation errors in the data
    def load_0_2_0(data)
      schemaPath = Pathname.new(::File.dirname(__FILE__)) + 'schema/sf-v0.2.0.yaml'
      schema = YAML.load_file(schemaPath.to_s)
      v = JSON::Validator.fully_validate(schema, data)
      return v unless v.empty?
      $cfg['tool.usingSolutionfile'] = true

      ifset(data, :default_page, @data[:assets], :default_page)
      ifset(data, :file_dir, @data[:assets], :location)

      @data[:routes].location = '.'
      @data[:routes][:include] = [data[:custom_api]] if data.has_key? :custom_api
      ifset(data, :cors, @data[:routes], :cors)

      if data.has_key? :modules then
        @data[:modules].location = '.'
        @data[:modules][:include] = data[:modules].values
      end

      if data.has_key? :event_handler then
        @data[:services].location = '.'
        evd = data[:event_handler].values.map{|e| e.values}.flatten
        @data[:services].include = evd
        @data.services.legacy = store_legacy_service_handlers(data[:event_handler])
      end
      []
    end
    alias load_0_2 load_0_2_0

    def store_legacy_service_handlers(services)
      ret = {}
      services.each do |service, events|
        events.each do |event, path|
          ret[path] = [service, event]
        end
      end
      ret
    end

    # Load data in the 0.3.0 format.
    # @param data [Hash] the data to load
    # @return [Array] An array of validation errors in the data
    def load_0_3_0(data)
      schemaPath = Pathname.new(::File.dirname(__FILE__)) + 'schema/sf-v0.3.0.yaml'
      schema = YAML.load_file(schemaPath.to_s)
      v = JSON::Validator.fully_validate(schema, data)
      return v unless v.empty?
      $cfg['tool.usingSolutionfile'] = true

      ifset(data, :default_page, @data[:assets], :default_page)
      ifset(data, :assets, @data[:assets], :location)

      @data[:routes].location = '.'
      @data[:routes][:include] = [data[:routes]] if data.has_key? :routes
      ifset(data, :cors, @data[:routes], :cors)

      if data.has_key? :modules then
        @data[:modules].location = '.'
        @data[:modules][:include] = data[:modules].values
      end

      if data.has_key? :services then
        @data[:services].location = '.'
        evd = data[:services].values.map{|e| e.values}.flatten
        @data[:services].include = evd
        @data.services.legacy = store_legacy_service_handlers(data[:services])
      end

      []
    end
    alias load_0_3 load_0_3_0
    alias load_0 load_0_3_0
  end


end
#  vim: set ai et sw=2 ts=2 :
