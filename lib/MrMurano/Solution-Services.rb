require 'uri'
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
      raise "Needs to be implemented in child"
    end

    def mkname(remote)
      raise "Needs to be implemented in child"
    end

    def list
      ret = get()
      ret[:items]
    end

    def fetch(name)
      raise "Missing name!" if name.nil?
      raise "Empty name!" if name.empty?
      ret = get('/'+name)
      if block_given? then
        yield ret[:script]
      else
        ret[:script]
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

      pst = remote.merge ({
        :solution_id => $cfg['solution.id'],
        :script => script,
        :alias=>mkalias(remote),
        :name=>mkname(remote),
      })
      debug "f: #{local} >> #{pst.reject{|k,_| k==:script}.to_json}"
      # try put, if 404, then post.
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

  # …/library
  class Library < ServiceBase
    def initialize
      super
      @uriparts << 'library'
      @itemkey = :alias
      @location = $cfg['location.modules']
    end

    def tolocalname(item, key)
      name = item[:name]
      "#{name}.lua"
    end

    def mkalias(remote)
      if remote.has_key? :name then
        [$cfg['solution.id'], remote[:name]].join('_')
      else
        raise "Missing parts! #{remote.to_json}"
      end
    end

    def mkname(remote)
      if remote.has_key? :name then
        remote[:name]
      else
        raise "Missing parts! #{remote.to_json}"
      end
    end

    def searchFor
      $cfg['modules.searchFor'].split
    end

    def ignoring
      $cfg['modules.ignoring'].split
    end

    def toRemoteItem(from, path)
      name = path.basename.to_s.sub(/\..*/, '')
      {:name => name}
    end

    def synckey(item)
      item[:name]
    end
  end
  SyncRoot.add('modules', Library, 'M', %{Modules}, true)

  # …/eventhandler
  class EventHandler < ServiceBase
    def initialize
      super
      @uriparts << 'eventhandler'
      @itemkey = :alias
      @location = $cfg['location.eventhandlers']
      @match_header = /--#EVENT (?<service>\S+) (?<event>\S+)/
    end

    def mkalias(remote)
      if remote.has_key? :service and remote.has_key? :event then
        [$cfg['solution.id'], remote[:service], remote[:event]].join('_')
      else
        raise "Missing parts! #{remote.to_json}"
      end
    end

    def mkname(remote)
      if remote.has_key? :service and remote.has_key? :event then
        [remote[:service], remote[:event]].join('_')
      else
        raise "Missing parts! #{remote.to_json}"
      end
    end

    def searchFor
      $cfg['eventhandler.searchFor'].split
    end

    def ignoring
      $cfg['eventhandler.ignoring'].split
    end

    def list
      ret = get()
      # eventhandler.skiplist is a list of whitespace seperated dot-paired values.
      # fe: service.event service service service.event
      skiplist = ($cfg['eventhandler.skiplist'] or '').split
      ret[:items].reject { |i|
        i.has_key?(:service) and i.has_key?(:event) and
        ( skiplist.include? i[:service] or
          skiplist.include? "#{i[:service]}.#{i[:event]}"
        )
      }
    end

    def fetch(name)
      ret = get('/'+name)
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
      path = Pathname.new(path) unless path.kind_of? Pathname
      cur = nil
      lineno=0
      path.readlines().each do |line|
        md = @match_header.match(line)
        if not md.nil? then
          # header line.
          cur = {:service=>md[:service],
                 :event=>md[:event],
                 :local_path=>path,
                 :line=>lineno,
                 :script=>line}
        elsif not cur.nil? and not cur[:script].nil? then
          cur[:script] << line
        end
        lineno += 1
      end
      cur[:line_end] = lineno unless cur.nil?
      cur
    end

    def synckey(item)
      "#{item[:service]}_#{item[:event]}"
    end
  end
  SyncRoot.add('eventhandlers', EventHandler, 'E', %{Event Handlers}, true)

end
#  vim: set ai et sw=2 ts=2 :
