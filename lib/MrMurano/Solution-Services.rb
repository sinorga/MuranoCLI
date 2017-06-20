require 'uri'
require 'cgi'
require 'net/http'
require 'json'
require 'yaml'
require 'date'
require 'digest/sha1'
require 'MrMurano/Solution'

module MrMurano
  ##
  # Things that servers do that is common.
  class ServiceBase < SolutionBase

    def mkalias(remote)
      # :nocov:
      raise "Needs to be implemented in child"
      # :nocov:
    end

    def mkname(remote)
      # :nocov:
      raise "Needs to be implemented in child"
      # :nocov:
    end

    def fetch(name)
      raise "Missing name!" if name.nil?
      raise "Empty name!" if name.empty?
      ret = get('/'+CGI.escape(name))
      error "Unexpected result type, assuming empty instead: #{ret}" unless ret.kind_of? Hash
      ret = {} unless ret.kind_of? Hash
      if block_given? then
        yield (ret[:script] or '')
      else
        ret[:script] or ''
      end
    end

    # ??? remove
    def remove(name)
      delete('/'+name)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify=false)
      local = Pathname.new(local) unless local.kind_of? Pathname
      raise "no file" unless local.exist?

      # we assume these are small enough to slurp.
      script = local.read

      pst = remote.to_h.merge({
        :solution_id => $cfg[@solntype],
        :script => script,
        :alias => mkalias(remote),
        :name => mkname(remote),
      })
      debug "f: #{local} >> #{pst.reject{|k,_| k==:script}.to_json}"
      # Try PUT. If 404, then POST.
      # I.e., PUT if not exists, else POST to create.
      put('/'+mkalias(remote), pst) do |request, http|
        response = http.request(request)
        case response
        when Net::HTTPSuccess
          #return JSON.parse(response.body)
        when Net::HTTPNotFound
          verbose "Doesn't exist, creating"
          post('/', pst)
        else
          showHttpError(request, response)
        end
      end
      cacheUpdateTimeFor(local)
    end

    def docmp(itemA, itemB)
      if itemA[:updated_at].nil? and itemA[:local_path] then
        ct = cachedUpdateTimeFor(itemA[:local_path])
        itemA[:updated_at] = ct unless ct.nil?
        itemA[:updated_at] = itemA[:local_path].mtime.getutc if ct.nil?
      elsif itemA[:updated_at].kind_of? String then
        itemA[:updated_at] = DateTime.parse(itemA[:updated_at]).to_time.getutc
      end
      if itemB[:updated_at].nil? and itemB[:local_path] then
        ct = cachedUpdateTimeFor(itemB[:local_path])
        itemB[:updated_at] = ct unless ct.nil?
        itemB[:updated_at] = itemB[:local_path].mtime.getutc if ct.nil?
      elsif itemB[:updated_at].kind_of? String then
        itemB[:updated_at] = DateTime.parse(itemB[:updated_at]).to_time.getutc
      end
      return itemA[:updated_at].to_time.round != itemB[:updated_at].to_time.round
    end

    def cacheFileName
      ['cache',
       self.class.to_s.gsub(/\W+/,'_'),
       @sid,
       'yaml'].join('.')
    end

    def cacheUpdateTimeFor(local_path, time=nil)
      time = Time.now.getutc if time.nil?
      entry = {
        :sha1=>Digest::SHA1.file(local_path.to_s).hexdigest,
        :updated_at=>time.to_datetime.iso8601(3)
      }
      cacheFile = $cfg.file_at(cacheFileName)
      if cacheFile.file? then
        cacheFile.open('r+') do |io|
          cache = YAML.load(io)
          cache = {} unless cache
          io.rewind
          cache[local_path.to_s] = entry
          io << cache.to_yaml
        end
      else
        cacheFile.open('w') do |io|
          cache = {}
          cache[local_path.to_s] = entry
          io << cache.to_yaml
        end
      end
      time
    end

    def cachedUpdateTimeFor(local_path)
      cksm = Digest::SHA1.file(local_path.to_s).hexdigest
      cacheFile = $cfg.file_at(cacheFileName)
      return nil unless cacheFile.file?
      ret = nil
      cacheFile.open('r') do |io|
        cache = YAML.load(io)
        return nil unless cache
        if cache.has_key?(local_path.to_s) then
          entry = cache[local_path.to_s]
          debug("For #{local_path}:")
          debug(" cached: #{entry.to_s}")
          debug(" cm: #{cksm}")
          if entry.kind_of?(Hash) then
            if entry[:sha1] == cksm and entry.has_key?(:updated_at) then
              ret = DateTime.parse(entry[:updated_at])
            end
          end
        end
      end
      ret
    end
  end

  # Libraries or better known as Modules.
  class Library < ServiceBase
    # Module Specific details on an Item
    class LibraryItem < Item
      # @return [String] Internal Alias name
      attr_accessor :alias
      # @return [String] Timestamp when this was updated.
      attr_accessor :updated_at
      # @return [String] Timestamp when this was created.
      attr_accessor :created_at
      # @return [String] The application solution's ID.
      attr_accessor :solution_id
    end

    def initialize
      super
      @uriparts << 'library'
      @itemkey = :alias
      @project_section = :modules
    end

    def tolocalname(item, key)
      name = item[:name]
      "#{name}.lua"
    end

    def mkalias(remote)
      unless remote.name.nil? then
        [$cfg[@solntype], remote[:name]].join('_')
      else
        raise "Missing parts! #{remote.to_h.to_json}"
      end
    end

    def mkname(remote)
      unless remote.name.nil? then
        remote[:name]
      else
        raise "Missing parts! #{remote.to_h.to_json}"
      end
    end

    def list
      ret = get()
      return [] unless ret.is_a?(Hash) and !ret.has_key?(:error)
      return [] unless ret.has_key?(:items)
      ret[:items].map{|i| LibraryItem.new(i)}
    end

    def toRemoteItem(from, path)
      name = path.basename.to_s.sub(/\..*/, '')
      LibraryItem.new(:name => name)
    end

    def synckey(item)
      item[:name]
    end
  end
  SyncRoot.add('modules', Library, 'M', %{Modules}, true)

  # Services aka EventHandlers
  class EventHandler < ServiceBase
    # EventHandler Specific details on an Item
    class EventHandlerItem < Item
      # @return [String] Internal Alias name
      attr_accessor :alias
      # @return [String] Timestamp when this was updated.
      attr_accessor :updated_at
      # @return [String] Timestamp when this was created.
      attr_accessor :created_at
      # @return [String] The soln's product.id or application.id (Murano's apiId).
      attr_accessor :solution_id
      # @return [String] Which service triggers this script
      attr_accessor :service
      # @return [String] Which event triggers this script
      attr_accessor :event
      # @return [String] For device2 events, the type of event
      attr_accessor :type
    end

    def initialize
      super
      @uriparts << 'eventhandler'
      @itemkey = :alias
      #@project_section = :services
      unless @project_section
        raise "Subclass missing @project_section"
      end
      @match_header = /--#EVENT (?<service>\S+) (?<event>\S+)/
    end

    def mkalias(remote)
      if remote.service.nil? or remote.event.nil? then
        raise "Missing parts! #{remote.to_h.to_json}"
      else
        [$cfg[@solntype], remote[:service], remote[:event]].join('_')
      end
    end

    def mkname(remote)
      if remote.service.nil? or remote.event.nil? then
        raise "Missing parts! #{remote.to_h.to_json}"
      else
        [remote[:service], remote[:event]].join('_')
      end
    end

    def list
      ret = get()
      return [] if ret.is_a?(Hash) and ret.has_key?(:error)
      # eventhandler.skiplist is a list of whitespace separated dot-paired values.
      # fe: service.event service service service.event
      skiplist = ($cfg['eventhandler.skiplist'] or '').split
      ret[:items].reject { |i|
        i.has_key?(:service) and i.has_key?(:event) and
        ( skiplist.include? i[:service] or
          skiplist.include? "#{i[:service]}.#{i[:event]}"
        )
      }.map{|i| EventHandlerItem.new(i)}
    end

    def fetch(name)
      ret = get('/'+CGI.escape(name))
      if ret.nil? then
        error "Fetch for #{name} returned nil; skipping"
        return ''
      end
      aheader = (ret[:script].lines.first or "").chomp
      dheader = "--#EVENT #{ret[:service]} #{ret[:event]}"
      if block_given? then
        yield dheader + "\n" if aheader != dheader
        yield ret[:script]
      else
        res = ''
        res << dheader + "\n" if aheader != dheader
        res << ret[:script]
        res
      end
    end

    def tolocalname(item, key)
      "#{item[:name]}.lua"
    end

    def toRemoteItem(from, path)
      # This allows multiple events to be in the same file. This is a lie.
      # This only finds the last event in a file.
      # :legacy support doesn't allow for that. But that's ok.
      path = Pathname.new(path) unless path.kind_of? Pathname
      cur = nil
      lineno=0
      path.readlines().each do |line|
        md = @match_header.match(line)
        if not md.nil? then
          # [lb] asks: Is this too hacky?
          if md[:service] == 'device2' then
            event_event = 'event'
            event_type = md[:event]
          else
            event_event = md[:event]
            event_type = nil
          end
          # header line.
          cur = EventHandlerItem.new(:service=>md[:service],
                                     :event=>event_event,
                                     :type=>event_type,
                                     :local_path=>path,
                                     :line=>lineno,
                                     :script=>line)
        elsif not cur.nil? and not cur[:script].nil? then
          cur[:script] << line
        end
        lineno += 1
      end
      cur[:line_end] = lineno unless cur.nil?

      # If cur is nil here, then we need to do a :legacy check.
      if cur.nil? and $project['services.legacy'].kind_of? Hash then
        spath = path.relative_path_from(from)
        debug "No headers: #{spath}"
        service, event = $project['services.legacy'][spath.to_s]
        debug "Legacy lookup #{spath} => [#{service}, #{event}]"
        unless service.nil? or event.nil? then
          warning "Event in #{spath} missing header, but has legacy support."
          warning "Please add the header \"--#EVENT #{service} #{event}\""
          cur = EventHandlerItem.new(:service=>service,
                                     :event=>event,
                                     :type=>nil,
                                     :local_path=>path,
                                     :line=>0,
                                     :line_end => lineno,
                                     :script=>path.read() # FIXME: ick, fix this.
                                    )
        end
      end
      cur
    end

    def match(item, pattern)
      # Pattern is: #{service}#{event}
      pattern_pattern = /^#(?<service>[^#]*)#(?<event>.*)/i
      md = pattern_pattern.match(pattern)
      return false if md.nil?
      debug "match pattern: '#{md[:service]}' '#{md[:event]}'"

      unless md[:service].empty? then
        return false unless item[:service].downcase == md[:service].downcase
      end

      unless md[:event].empty? then
        return false unless item[:event].downcase == md[:event].downcase
      end

      true # Both match (or are empty.)
    end

    def synckey(item)
      "#{item[:service]}_#{item[:event]}"
    end
  end

  PRODUCT_SERVICES = ["device2", "interface",]

  class EventHandlerSolnPrd < EventHandler
    def initialize
      @solntype = 'product.id'
      # FIXME/2017-06-20: Should we use separate directories for prod vs app?
      #   See also :services in PrfFile and elsewhere;
      #   we could use @@class_var to DRY.
      @project_section = :services
      super
    end

    ##
    # Get a list of local items filtered by solution type.
    # @return [Array<Item>] Product solution events found
    def locallist()
      llist = super
      # This is a kludge to distinguish between Product services
      # and Application services: assume that Murano only ever
      # identifies Product services as "device2" or "interface".
      # If this weren't always the case, we'd have two obvious options:
      #   1) Store Product and Application eventhandlers in separate
      #      directories (and update the SyncRoot.add()s, below); or,
      #   2) Put the solution type in the Lua script,
      #      e.g., change this:
      #        --#EVENT device2 data_in
      #      to this:
      #        --#EVENT product device2 data_in
      # For now, the @service indicator is sufficient.
      llist.select!{|i| PRODUCT_SERVICES.include? i.service }
      llist
    end
  end

  class EventHandlerSolnApp < EventHandler
    def initialize
      @solntype = 'application.id'
      # FIXME/2017-06-20: Should we use separate directories for prod vs app?
      @project_section = :services
      super
    end

    ##
    # Get a list of local items filtered by solution type.
    # @return [Array<Item>] Application solution events found
    def locallist()
      llist = super
      llist.select!{|i| not PRODUCT_SERVICES.include? i.service }
      llist
    end
  end

  SyncRoot.add('eventhandlers', EventHandlerSolnPrd, 'E', %{Product Event Handlers}, true)
  SyncRoot.add('eventhandlers', EventHandlerSolnApp, 'E', %{Application Event Handlers}, true)
  # FIXME/2017-06-20: Should we use separate directories for prod vs app?
  #   [lb] thinks so if the locallist()/PRODUCT_SERVICES kludge fails in the future.
  #SyncRoot.add('interfaces', EventHandlerSolnPrd, 'E', %{Product Event Handlers}, true)
  #SyncRoot.add('services', EventHandlerSolnApp, 'E', %{Application Event Handlers}, true)

end
#  vim: set ai et sw=2 ts=2 :
