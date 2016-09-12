require 'uri'
require 'net/http'
require 'json'
require 'pp'

module MrMurano
  ##
  # Things that servers do that is common.
  class ServiceBase < SolutionBase
    # not quite sure why this is needed, but…
    def mkalias(name)
      case name
      when String
        "/#{$cfg['solution.id']}_#{name}"
      when Hash
        if name.has_key? :name then
          "/#{$cfg['solution.id']}_#{name[:name]}"
        elsif name.has_key? :service and name.has_key? :event then
          "/#{$cfg['solution.id']}_#{name[:service]}_#{name[:event]}"
        else
          raise "unknown keys. #{name}"
        end
      else
        raise "unknown type. #{name}"
      end
    end

    def list
      ret = get()
      ret[:items]
    end

    def fetch(name)
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

    def upload(local, remote)
      local = Pathname.new(local) unless local.kind_of? Pathname
      raise "no file" unless local.exist?

      # we assume these are small enough to slurp.
      script = local.read

      pst = remote.merge ({
        :solution_id => $cfg['solution.id'],
        :script => script
      })

      # try put, if 404, then post.
      put(mkalias(remote), pst) do |request, http|
        response = http.request(request)
        case response
        when Net::HTTPSuccess
          #return JSON.parse(response.body)
        when Net::HTTPNotFound
          verbose "Doesn't exist, creating"
          post('/', pst)
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
        end
      end
    end

    def docmp(itemA, itemB)
      if itemA[:updated_at].nil? and itemA[:local_path] then
        itemA[:updated_at] = itemA[:local_path].mtime.getutc
      elsif itemA[:updated_at].kind_of? String then
        itemA[:updated_at] = DateTime.parse(itemA[:updated_at]).to_time.getutc
      end
      if itemB[:updated_at].nil? and itemB[:local_path] then
        itemB[:updated_at] = itemB[:local_path].mtime.getutc
      elsif itemB[:updated_at].kind_of? String then
        itemB[:updated_at] = DateTime.parse(itemB[:updated_at]).to_time.getutc
      end
      # It is a common thing that the thing in murano has a newer updated timestamp
      # than the file here on disk.
      return itemA[:updated_at] != itemB[:updated_at]
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


    def toRemoteItem(from, path)
      name = path.basename.to_s.sub(/\..*/, '')
      {:name => name}
    end

    def synckey(item)
      item[:name]
    end
  end

  # …/eventhandler
  class EventHandler < ServiceBase
    def initialize
      super
      @uriparts << 'eventhandler'
      @itemkey = :alias
      @location = $cfg['location.eventhandlers']
    end

    def list
      ret = get()
      skiplist = ($cfg['eventhandler.skiplist'] or '').split
      ret[:items].reject{|i| i.has_key?(:service) and skiplist.include? i[:service] }
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
      aheader = path.readlines().first
      md = /--#EVENT (\S+) (\S+)/.match(aheader)
      if md.nil? then
        rp = path.relative_path_from(Pathname.new(Dir.pwd))
        say_warning "Not an Event handler: #{rp}"
        return nil
      end
      {:service=>md[1], :event=>md[2]}
    end

    def synckey(item)
      "#{item[:service]}_#{item[:event]}"
    end
  end

  # How do we enable product.id to flow into the eventhandler?
end
#  vim: set ai et sw=2 ts=2 :
