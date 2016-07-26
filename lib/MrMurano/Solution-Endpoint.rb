require 'uri'
require 'net/http'
require 'json'
require 'pp'

module MrMurano
  # …/endpoint
  class Endpoint < SolutionBase
    def initialize
      super
      @uriparts << 'endpoint'
    end

    ##
    # This gets all data about all endpoints
    def list
      get()
    end

    def fetch(id)
      ret = get('/' + id.to_s)
      aheader = ret['script'].lines.first.chomp
      dheader = "--#ENDPOINT #{ret['method']} #{ret['path']}"
      if block_given? then
        yield dheader + "\n" if aheader != dheader
        yield ret['script']
      else
        res = ''
        res << dheader + "\n" if aheader != dheader
        res << ret['script']
        res
      end
    end

    ##
    # Upload endpoint 
    # :local path to file to push
    # :remote hash of method and endpoint path
    def upload(local, remote)
      local = Pathname.new(local) unless local.kind_of? Pathname
      raise "no file" unless local.exist?

      # we assume these are small enough to slurp.
      script = local.read
      remote = remote.dup
      remote[:script] = script
      #post('', remote)
      put('/' + remote[@itemkey], remote) do |request, http|
        response = http.request(request)
        case response
        when Net::HTTPSuccess
          #return JSON.parse(response.body)
        when Net::HTTPNotFound
          verbose "Doesn't exist, creating"
          post('/', remote)
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
        end
      end
    end

    ##
    # Delete an endpoint
    def remove(id)
      delete('/' + id.to_s)
    end

    def tolocalname(item, key)
      name = item[:method].downcase
      name << '_'
      name << item[:path].gsub(/\//, '-')
      name << '.lua'
    end

    def toremotename(from, path)
      # read first line of file and get method/path from it?
      path = Pathname.new(path) unless path.kind_of? Pathname
      aheader = path.readlines().first
      md = /--#ENDPOINT (\S+) (.*)/.match(aheader)
      raise "Not an Endpoint: #{path.to_s}" if md.nil?
      {:method=>md[1], :path=>md[2]}
    end

    def synckey(item)
      "#{item[:method].upcase}_#{item[:path]}"
    end

  end

end
#  vim: set ai et sw=2 ts=2 :
