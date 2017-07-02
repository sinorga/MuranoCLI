# Last Modified: 2017.07.02 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'cgi'
require 'date'
require 'digest/sha1'
require 'json'
require 'net/http'
require 'uri'
require 'yaml'
require 'MrMurano/Solution'

module MrMurano
  ##
  # Things that servers do that is common.
  class ServiceBase < SolutionBase
    def mkalias(_remote)
      # :nocov:
      raise 'Needs to be implemented in child'
      # :nocov:
    end

    def mkname(_remote)
      # :nocov:
      raise 'Needs to be implemented in child'
      # :nocov:
    end

    def fetch(name)
      raise 'Missing name!' if name.nil?
      raise 'Empty name!' if name.empty?
      ret = get('/' + CGI.escape(name))
      error "Unexpected result type, assuming empty instead: #{ret}" unless ret.is_a?(Hash)
      ret = {} unless ret.is_a?(Hash)
      if block_given?
        yield (ret[:script] || '')
      else
        ret[:script] || ''
      end
    end

    # ??? remove
    def remove(name)
      delete('/' + name)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, _modify=false)
      local = Pathname.new(local) unless local.is_a?(Pathname)
      raise 'no file' unless local.exist?

      # we assume these are small enough to slurp.
      script = local.read

      pst = remote.to_h.merge(
        #solution_id: $cfg[@solntype],
        solution_id: @sid,
        script: script,
        alias: mkalias(remote),
        name: mkname(remote),
      )
      debug "f: #{local} >> #{pst.reject { |k, _| k == :script }.to_json}"
      # Try PUT. If 404, then POST.
      # I.e., PUT if not exists, else POST to create.
      put('/' + mkalias(remote), pst) do |request, http|
        response = http.request(request)
        case response
        # rubocop:disable Lint/EmptyWhen: "Avoid when branches without a body."
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

    def docmp(item_a, item_b)
      if item_a[:updated_at].nil? && item_a[:local_path]
        ct = cached_update_time_for(item_a[:local_path])
        item_a[:updated_at] = ct unless ct.nil?
        item_a[:updated_at] = item_a[:local_path].mtime.getutc if ct.nil?
      elsif item_a[:updated_at].is_a?(String)
        item_a[:updated_at] = DateTime.parse(item_a[:updated_at]).to_time.getutc
      end
      if item_b[:updated_at].nil? && item_b[:local_path]
        ct = cached_update_time_for(item_b[:local_path])
        item_b[:updated_at] = ct unless ct.nil?
        item_b[:updated_at] = item_b[:local_path].mtime.getutc if ct.nil?
      elsif item_b[:updated_at].is_a?(String)
        item_b[:updated_at] = DateTime.parse(item_b[:updated_at]).to_time.getutc
      end
      item_a[:updated_at].to_time.round != item_b[:updated_at].to_time.round
    end

    def cache_file_name
      [
        'cache',
        self.class.to_s.gsub(/\W+/, '_'),
        @sid,
        'yaml',
      ].join('.')
    end

    def cacheUpdateTimeFor(local_path, time=nil)
      time = Time.now.getutc if time.nil?
      entry = {
        sha1: Digest::SHA1.file(local_path.to_s).hexdigest,
        updated_at: time.to_datetime.iso8601(3),
      }
      cache_file = $cfg.file_at(cache_file_name)
      if cache_file.file?
        cache_file.open('r+') do |io|
          # FIXME/2017-07-02: "Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load."
          cache = YAML.load(io)
          cache = {} unless cache
          io.rewind
          cache[local_path.to_s] = entry
          io << cache.to_yaml
        end
      else
        cache_file.open('w') do |io|
          cache = {}
          cache[local_path.to_s] = entry
          io << cache.to_yaml
        end
      end
      time
    end

    def cached_update_time_for(local_path)
      cksm = Digest::SHA1.file(local_path.to_s).hexdigest
      cache_file = $cfg.file_at(cache_file_name)
      return nil unless cache_file.file?
      ret = nil
      cache_file.open('r') do |io|
        # FIXME/2017-07-02: "Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load."
        cache = YAML.load(io)
        return nil unless cache
        if cache.key?(local_path.to_s)
          entry = cache[local_path.to_s]
          debug("For #{local_path}:")
          debug(" cached: #{entry}")
          debug(" cm: #{cksm}")
          if entry.is_a?(Hash)
            if entry[:sha1] == cksm && entry.key?(:updated_at)
              ret = DateTime.parse(entry[:updated_at])
            end
          end
        end
      end
      ret
    end
  end

  # What Murano calls "Modules". Snippets of Lua code.
  class Module < ServiceBase
    # Module Specific details on an Item
    class ModuleItem < Item
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

    def tolocalname(item, _key)
      name = item[:name]
      "#{name}.lua"
    end

    def mkalias(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.name.nil?
      #[$cfg[@solntype], remote[:name]].join('_')
      [@sid, remote[:name]].join('_')
    end

    def mkname(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.name.nil?
      remote[:name]
    end

    def list
      ret = get
      return [] unless ret.is_a?(Hash) && !ret.key?(:error)
      return [] unless ret.key?(:items)
      ret[:items].map { |i| ModuleItem.new(i) }
    end

    def to_remote_item(_from, path)
      name = path.basename.to_s.sub(/\..*/, '')
      ModuleItem.new(name: name)
    end

    def synckey(item)
      item[:name]
    end
  end
  SyncRoot.add('modules', Module, 'M', %(Modules), true)

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

    def initialize(sid)
      super
      @uriparts << 'eventhandler'
      @itemkey = :alias
      #@project_section = :services
      raise 'Subclass missing @project_section' unless @project_section
      @match_header = /--#EVENT (?<service>\S+) (?<event>\S+)/
    end

    def mkalias(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.service.nil? || remote.event.nil?
      #[$cfg[@solntype], remote[:service], remote[:event]].join('_')
      [@sid, remote[:service], remote[:event]].join('_')
    end

    def mkname(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.service.nil? || remote.event.nil?
      [remote[:service], remote[:event]].join('_')
    end

    def list(call=nil, data=nil, &block)
      ret = get(call, data, &block)
      return [] if ret.is_a?(Hash) && ret.key?(:error)
      # eventhandler.skiplist is a list of whitespace separated dot-paired values.
      # fe: service.event service service service.event
      skiplist = ($cfg['eventhandler.skiplist'] || '').split
      items = ret[:items].reject do |i|
        keep = (
          i.key?(:service) &&
          i.key?(:event) && (
            skiplist.include?(i[:service]) ||
            skiplist.include?("#{i[:service]}.#{i[:event]}")
          )
        )
        keep
      end
      items.map { |i| EventHandlerItem.new(i) }
    end

    def fetch(name)
      ret = get('/' + CGI.escape(name))
      if ret.nil?
        error "Fetch for #{name} returned nil; skipping"
        return ''
      end
      aheader = (ret[:script].lines.first || '').chomp
      dheader = "--#EVENT #{ret[:service]} #{ret[:event]}"
      if block_given?
        yield dheader + "\n" if aheader != dheader
        yield ret[:script]
      else
        res = ''
        res << dheader + "\n" if aheader != dheader
        res << ret[:script]
        res
      end
    end

    def default_event_script(service_or_sid, &block)
      post(
        '/',
        {
          solution_id: @sid,
          service: service_or_sid,
          event: 'event',
          script: 'print(event)',
        },
        &block
      )
    end

    def tolocalname(item, _key)
      "#{item[:name]}.lua"
    end

    def to_remote_item(from, path)
      # This allows multiple events to be in the same file. This is a lie.
      # This only finds the last event in a file.
      # :legacy support doesn't allow for that. But that's ok.
      path = Pathname.new(path) unless path.is_a?(Pathname)
      cur = nil
      lineno = 0
      path.readlines.each do |line|
        md = @match_header.match(line)
        if !md.nil?
          # [lb] asks: Is this too hacky?
          if md[:service] == 'device2'
            event_event = 'event'
            event_type = md[:event]
          else
            event_event = md[:event]
            event_type = nil
          end
          # header line.
          cur = EventHandlerItem.new(
            service: md[:service],
            event: event_event,
            type: event_type,
            local_path: path,
            line: lineno,
            script: line,
          )
        elsif !cur.nil? && !cur[:script].nil?
          cur[:script] << line
        end
        lineno += 1
      end
      cur[:line_end] = lineno unless cur.nil?

      # If cur is nil here, then we need to do a :legacy check.
      if cur.nil? && $project['services.legacy'].is_a?(Hash)
        spath = path.relative_path_from(from)
        debug "No headers: #{spath}"
        service, event = $project['services.legacy'][spath.to_s]
        debug "Legacy lookup #{spath} => [#{service}, #{event}]"
        unless service.nil? || event.nil?
          warning %(Event in #{spath} missing header, but has legacy support.)
          warning %(Please add the header "--#EVENT #{service} #{event}")
          cur = EventHandlerItem.new(
            service: service,
            event: event,
            type: nil,
            local_path: path,
            line: 0,
            line_end: lineno,
            script: path.read, # FIXME: ick, fix this.
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
      return false unless md[:service].empty? || item[:service].casecmp(md[:service])
      return false unless md[:event].empty? || item[:event].casecmp(md[:event])
      true # Both match (or are empty.)
    end

    def synckey(item)
      "#{item[:service]}_#{item[:event]}"
    end
  end

  PRODUCT_SERVICES = %w[device2 interface].freeze

  class EventHandlerSolnPrd < EventHandler
    def initialize(sid=nil)
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
    def locallist
      llist = super
      # This is a kludge to distinguish between Product services
      # and Application services: assume that Murano only ever
      # identifies Product services as 'device2' || 'interface'.
      # If this weren't always the case, we'd have two obvious options:
      #   1) Store Product and Application eventhandlers in separate
      #      directories (and update the SyncRoot.add()s, below); or,
      #   2) Put the solution type in the Lua script,
      #      e.g., change this:
      #        --#EVENT device2 data_in
      #      to this:
      #        --#EVENT product device2 data_in
      # For now, the @service indicator is sufficient.
      llist.select! { |i| PRODUCT_SERVICES.include? i.service }
      llist
    end
  end

  class EventHandlerSolnApp < EventHandler
    def initialize(sid=nil)
      @solntype = 'application.id'
      # FIXME/2017-06-20: Should we use separate directories for prod vs app?
      @project_section = :services
      super
    end

    ##
    # Get a list of local items filtered by solution type.
    # @return [Array<Item>] Application solution events found
    def locallist
      llist = super
      # "Style/InverseMethods: Use reject! instead of inverting select!."
      #llist.select! { |i| !PRODUCT_SERVICES.include? i.service }
      llist.reject! { |i| PRODUCT_SERVICES.include? i.service }
      llist
    end
  end

  # Order here matters, because spec/cmd_init_spec.rb
  SyncRoot.add('eventhandlers', EventHandlerSolnApp, 'E', %(Application Event Handlers), true)
  SyncRoot.add('eventhandlers', EventHandlerSolnPrd, 'E', %(Product Event Handlers), true)
  # FIXME/2017-06-20: Should we use separate directories for prod vs app?
  #   [lb] thinks so if the locallist/PRODUCT_SERVICES kludge fails in the future.
  #SyncRoot.add('services', EventHandlerSolnApp, 'E', %(Application Event Handlers), true)
  #SyncRoot.add('interfaces', EventHandlerSolnPrd, 'E', %(Product Event Handlers), true)
end

