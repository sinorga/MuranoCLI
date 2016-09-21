require 'uri'
require 'net/http'
require 'json'
require 'pp'
require 'MrMurano/Solution'

module MrMurano
  # …/endpoint
  class Endpoint < SolutionBase
    def initialize
      super
      @uriparts << 'endpoint'
      @location = $cfg['location.endpoints']
    end

    ##
    # This gets all data about all endpoints
    def list
      get()
    end

    def fetch(id)
      ret = get('/' + id.to_s)
      aheader = (ret[:script].lines.first or "").chomp
      dheader = /^--#ENDPOINT (?i:#{ret[:method]}) #{ret[:path]}$/
      rheader = %{--#ENDPOINT #{ret[:method]} #{ret[:path]}\n}
      if block_given? then
        yield rheader unless dheader =~ aheader
        yield ret[:script]
      else
        res = ''
        res << rheader unless dheader =~ aheader
        res << ret[:script]
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
      limitkeys = [:method, :path, :script, @itemkey]
      remote = remote.select{|k,v| limitkeys.include? k }
      remote[:script] = script
#      post('', remote)
      if remote.has_key? @itemkey then
        put('/' + remote[@itemkey], remote) do |request, http|
          response = http.request(request)
          case response
          when Net::HTTPSuccess
            #return JSON.parse(response.body)
          when Net::HTTPNotFound
            verbose "\tDoesn't exist, creating"
            post('/', remote)
          else
            say_error "got #{response} from #{request} #{request.uri.to_s}"
            say_error ":: #{response.body}"
          end
        end
      else
        verbose "\tNo itemkey, creating"
        post('/', remote)
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

    def toRemoteItem(from, path)
      # read first line of file and get method/path from it?
      path = Pathname.new(path) unless path.kind_of? Pathname
      aheader = path.readlines().first
      md = /--#ENDPOINT (\S+) (.*)/.match(aheader)
      if md.nil? then
        rp = path.relative_path_from(Pathname.new(Dir.pwd))
        say_warning "Not an Endpoint: #{rp.to_s}"
        return nil
      end
      {:method=>md[1], :path=>md[2]}
    end

    def synckey(item)
      "#{item[:method].upcase}_#{item[:path]}"
    end

    def docmp(itemA, itemB)
      if itemA[:script].nil? and itemA[:local_path] then
        itemA[:script] = itemA[:local_path].read
      end
      if itemB[:script].nil? and itemB[:local_path] then
        itemB[:script] = itemB[:local_path].read
      end
      return itemA[:script] != itemB[:script]
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
