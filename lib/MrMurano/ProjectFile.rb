require 'yaml'
require 'vine'
require 'json-schema'
require 'MrMurano/Config'
require 'MrMurano/hash'

module MrMurano
  ##
  # A Project File that describes details about a project that is synced into
  # Murano
  class ProjectFile

    # The contents of this is explictily not just a nest of hashes and arrays.
    # To keep expectations in check, there is a set number of known keys.
    # This should also help by keeping the file format seperate from the internal
    # lookups.  Hopefully, this will avoid (or at least minimize) changes to the
    # file format affecting all kinds of code.
    PrjMeta = Struct.new(:name, :summary, :description, :authors, :version, :source, :dependencies) do
      def load(obj)
        self.members.each do |key|
          self[key] = obj[key] if obj.has_key? key
        end
      end
      def save
        ret={}
        self.members.each do |key|
          ret[key] = self[key] unless self[key].nil?
        end
        ret
      end
    end

    PrjFiles = Struct.new(:location, :include, :exclude, :default_page) do
      def load(obj)
        self.members.each do |key|
          self[key] = obj[key] if obj.has_key? key
        end
      def save
        ret={}
        self.members.each do |key|
          ret[key] = self[key] unless self[key].nil?
        end
        ret
      end
    end

    PrjModules = Struct.new(:location, :include, :exclude) do
      def load(obj)
        self.members.each do |key|
          self[key] = obj[key] if obj.has_key? key
        end
      def save
        ret={}
        self.members.each do |key|
          ret[key] = self[key] unless self[key].nil?
        end
        ret
      end
    end

    PrjEndpoints = Struct.new(:location, :include, :exclude) do
      def load(obj)
        self.members.each do |key|
          self[key] = obj[key] if obj.has_key? key
        end
      def save
        ret={}
        self.members.each do |key|
          ret[key] = self[key] unless self[key].nil?
        end
        ret
      end
    end

    PrjEventHandlers = Struct.new(:location, :include, :exclude) do
      def load(obj)
        self.members.each do |key|
          self[key] = obj[key] if obj.has_key? key
        end
      def save
        ret={}
        self.members.each do |key|
          ret[key] = self[key] unless self[key].nil?
          # TODO don't add if equal to default.
        end
        ret
      end
    end
    #PrjCors = Struct.new(:origin, :methods, :headers, :credentials)

    PrfFile = Struct.new(:info, :assets, :modules, :routes, :eventhandlers) do
      def save
        ret={}
        self.members.each do |key|
          ret[key] = self[key].save
        end
        ret
      end
    end

    def initialize()
      @prjFile = nil
      tname = $cfg['location.base'].basename.to_s
      @data = PrfFile.new(
        PrjMeta.new(
          tname,
          "One line summary of #{tname}",
          "In depth description of #{tname}\n\nWith lots of details.",
          [$cfg['user.name']],
          "1.0.0",
          nil,
          nil
        ), #TODO: Fill out some default meta.
        PrjFiles.new($cfg['location.files'], $cfg['files.searchFor'], $cfg['files.ignoring'], $cfg['files.default_page']),
        PrjModules.new($cfg['location.modules'], $cfg['modules.searchFor'], $cfg['modules.ignoring']),
        PrjEndpoints.new($cfg['location.endpoints'], $cfg['endpoints.searchFor'], $cfg['endpoints.ignoring']),
        PrjEventHandlers.new($cfg['location.eventhandler'], $cfg['eventhandler.searchFor'], $cfg['eventhandler.ignoring']),
      )
    end

    # Get a value for a key.
    # Keys are 'section.key'
    def get(key)
      section, ikey = key.split('.')
      begin
        return @data[section.to_sym][ikey.to_sym]
      rescue NameError => e
        debug ">>=>> #{e}"
        return nil
      end
    end
    alias [] get

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
    def save
      dt = @data.save
      puts Hash.transform_keys_to_strings(dt).to_yaml

    end

    ##
    # Load the project file in the project directory.
    def load
      possible = $cfg['location.base'].glob('*.murano', 'SolutionFile.json')
      debug "Possible Project files: #{possible}"
      return 0 if possible.empty? # this is ok.

      @prjFile = possible.first
      if @prjFile.nil? then
        error "No project file found!"
        return -1
      end

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

      data = Hash.transform_key_to_symbols(data)

      # get format version
      fmtvers = (data[:formatversion] or data[:fmtvers] or '1.0.0')

      methodname = "load_#{fmtvers.gsub(/\./, '_')}".to_sym
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

    def ifset(src, skey, dest, dkey)
      dest[dkey] = src[skey] if src.has_key? skey
    end

    def load_1_0_0(data)
      # TODO: Schema Validation.
      @data.each_pair do |key, str|
        str.load(data[key]) if data.has_key? key
      end

      []
    end
    alias load_1_0 load_1_0_0
    alias load_1 load_1_0_0

    def load_0_2_0(data)
      schemaPath = Pathname.new(File.dirname(__FILE__)) + 'schema/sf-v0.2.0.yaml'
      schema = YAML.load_file(schemaPath.to_s)
      v = JSON::Validator.fully_validate(schema, data)
      return v unless v.empty?

      ifset(data, 'default_page', @data[:assets], :default_page)
      ifset(data, 'file_dir', @data[:assets], :location)

      ifset(data, 'custom_api', @data[:routes], :include)

      if data.has_key? 'modules' then
        @data[:modules][:include] = data['modules'].values
      end

      if data.has_key? 'event_handler' then
        evd = data['event_handler'].values.map{|e| e.values}.flatten
        @data[:eventhandlers].include = evd
      end
      # TODO: check if eventhandlers need header added.

      # TODO: cors.

      []
    end
    alias load_0_2 load_0_2_0

    def load_0_3_0(data)
      schemaPath = Pathname.new(File.dirname(__FILE__)) + 'schema/sf-v0.3.0.yaml'
      schema = YAML.load_file(schemaPath.to_s)
      v = JSON::Validator.fully_validate(schema, data)
      return v unless v.empty?

      ifset(data, 'default_page', @data[:assets], :default_page)
      ifset(data, 'assets', @data[:assets], :location)

      ifset(data, 'routes', @data[:routes], :include)

      if data.has_key? 'modules' then
        @data[:modules][:include] = data['modules'].values
      end

      if data.has_key? 'services' then
        evd = data['services'].values.map{|e| e.values}.flatten
        @data[:eventhandlers].include = evd
      end
      # TODO: check if eventhandlers need header added.

      # TODO: cors.

      []
    end
    alias load_0_3 load_0_3_0
    alias load_0 load_0_3_0
  end


end
#  vim: set ai et sw=2 ts=2 :
