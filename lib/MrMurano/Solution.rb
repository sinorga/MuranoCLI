require 'uri'
require 'net/http'
require 'net/http/post/multipart'
require 'json'
require 'date'
require 'pp'

module MrMurano
  class SolutionBase
    def initialize
      @token = Account.new.token
      @sid = $cfg['solution.id']
      raise "No solution!" if @sid.nil?
      @uriparts = [:solution, @sid]
    end

    def endPoint(path='')
      parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
      s = parts.map{|v| v.to_s}.join('/')
      URI(s + path.to_s)
    end
    def http
      uri = URI('https://' + $cfg['net.host'])
      if @http.nil? then
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = true
        @http.start
      end
      @http
    end

    def set_req_defaults(request)
      request.content_type = 'application/json'
      request['authorization'] = 'token ' + @token
      request
    end

    def workit(request, &block)
      set_req_defaults(request)
      if block_given? then
        yield request, http()
      else
        response = http().request(request)
        case response
        when Net::HTTPSuccess
          return JSON.parse(response.body)
        else
          raise response
        end
      end
    end

    def get(path='', &block)
      uri = endPoint(path)
      workit(Net::HTTP::Get.new(uri), &block) 
    end

    def post(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Post.new(uri)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def put(path='', &block)
      uri = endPoint(path)
      workit(Net::HTTP::Put.new(uri))
    end

    def delete(path='', &block)
      uri = endPoint(path)
      workit(Net::HTTP::Delete.new(uri))
    end

    # …

  end
  class Solution < SolutionBase
    def version
      get('/version')
    end

    def info
      get()
    end

    # …/serviceconfig
    def sc
      get('/serviceconfig/')
    end
    #
  end

  # …/file 
  class File < SolutionBase
    def initialize
      super
      @uriparts << 'file'
    end

    ##
    # Get a list of all of the static content
    def list
      get()
    end

    ##
    # Get one item of the static content.
    def fetch(path, &block)
      get('/'+path) do |request, http|
        http.request(request) do |resp|
          case resp
          when Net::HTTPSuccess
            if block_given? then
              resp.read_body &block
            else
              resp.read_body do |chunk|
                $stdout.write chunk
              end
            end
          else
            raise resp
          end
        end
        nil
      end
    end

    ##
    # Delete a file
    def remove(path)
      delete('/'+path) do |request, http|
        response = http.request(request)
        case response
        when Net::HTTPSuccess
          busy = JSON.parse(response.body)
          return busy
        else
          raise response
        end
      end
    end

    ##
    # Upload a file
    def upload(path, localfile)
      # mime=`file -I -b #{file}`
      # mime='application/octect' if mime.nil?
      uri = endPoint('upload/' + path)
      upper = UploadIO.new(File.new(localfile), type, name)
			req = Net::HTTP::Post::Multipart.new(uri, 'file'=> upper )
      workit(req)
    end

  end

  # …/role
  # …/user

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

    ##
    # Create endpoint
    def create(method, path, script)
      post('', {:method=>method, :path=>path, :script=>script})
    end

    ##
    # Delete an endpoint
    def remove(id)
      delete('/'+id)
    end
  end

end

command :solution do |c|
  c.syntax = %{mr solution ...}

  c.action do |args, options|

    sol = MrMurano::File.new
    say sol.fetch('')

  end
end

#  vim: set ai et sw=2 ts=2 :
