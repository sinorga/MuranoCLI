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
      ret['items']
    end

    def fetch(name)
      ret = get('/'+name)
      if block_given? then
        yield ret['script']
      else
        ret['script']
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

  end

  # …/library
  class Library < ServiceBase
    def initialize
      super
      @uriparts << 'library'
      @itemkey = :alias
    end

    # TODO: Support having a folder of a module.
    # Right now, this assumes that everything in local is a file
    # Add suport that it could be a directory that has a .rockspec
    # Lacking the .rockspec, do what? (ignore?)

    def tolocalname(item, key)
      name = item[:name]
#      altpath = $cfg["modules.pathfor_#{name}"]
#      if not altpath.nil? then
#        return altpath
#      else
        "#{name}.lua"
#      end
    end

    def toremotename(from, path)
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
    end

    def list
      ret = get()
      skiplist = ($cfg['eventhandler.skiplist'] or '').split
      ret['items'].reject{|i| i.has_key?('service') and skiplist.include? i['service'] }
    end

    def tolocalname(item, key)
      "#{item[:name]}.lua"
    end

    def toremotename(from, path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      aheader = path.readlines().first
      md = /--#EVENT (\S+) (\S+)/.match(aheader)
      raise "Not an Event handler: #{path.to_s}" if md.nil?
      {:service=>md[1], :event=>md[2]}
    end

    def synckey(item)
      "#{item[:service]}_#{item[:event]}"
    end
  end

  # How do we enable product.id to flow into the eventhandler?
end
#  vim: set ai et sw=2 ts=2 :
