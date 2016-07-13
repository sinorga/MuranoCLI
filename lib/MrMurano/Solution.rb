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
          say_error "got #{response} from #{request} #{request.uri.to_s}"
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
      # TODO test
      delete('/'+path)
    end

    ##
    # Upload a file
    def upload(path, localfile)
      # TODO finish and test this
      # mime=`file -I -b #{file}`
      # mime='application/octect' if mime.nil?
      uri = endPoint('upload/' + path)
      upper = UploadIO.new(File.new(localfile), type, name)
			req = Net::HTTP::Post::Multipart.new(uri, 'file'=> upper )
      workit(req)
    end

  end

  # …/role
  class Role < SolutionBase
    def initialize
      super
      @uriparts << 'role'
    end

    def list()
      get()
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    # delete
    # create
    # update?
  end

  # …/user
  class User < SolutionBase
    def initialize
      super
      @uriparts << 'user'
    end

    def list()
      get()
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    # delete
    # create
    # update?
  end

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
      get('/' + id.to_s)
    end

    ##
    # Create endpoint
    # This also acts as update.
    def create(method, path, script)
      post('', {:method=>method, :path=>path, :script=>script})
    end

    ##
    # Delete an endpoint
    def remove(id)
      delete('/' + id.to_s)
    end
  end

  # …/library
  class Library < SolutionBase
    def initialize
      super
      @uriparts << 'library'
    end

    def mkalias(name)
      "/#{$cfg['solution.id']}_#{name}"
    end

    def list
      get()
    end

    def fetch(name)
      get(mkalias(name))
    end

    # ??? remove

    def create(name, script)
      pst = {
        :name => name,
        :solution_id => $cfg['solution.id'],
        :script => script
      }
      post(mkalias(name), pst)
    end
    # XXX Or should create & update be merged into a single action?
    # Will think more on it when the sync methods get written.
    def update(name, script)
      pst = {
        :name => name,
        :solution_id => $cfg['solution.id'],
        :script => script
      }
      put(mkalias(name), pst)
    end
  end

  # …/eventhandler

  # How do we enable product.id to flow into the eventhandler?
end

#
# I think what I want for top level commands is a 
# - sync --up   : Make servers like my working dir
# - sync --down : Make working dir like servers
#   --no-delete : Don't delete things at destination
#   --no-create : Don't create things at destination
#   --no-update : Don't update things at destination
# 
# And then various specific commands.
# fe: mr file here there to upload a single file
#     mr file --pull there here
#
# or
#   mr pull --file here there
#   mr push --file here there
#   mr pull --[file,user,role,endpoint,…]
command :solution do |c|
  c.syntax = %{mr solution ...}

  c.action do |args, options|

    sol = MrMurano::User.new
    say sol.fetch('1')

  end
end

command :file do |c|
  c.syntax = %{mr file ……}
  c.option '--pullall DIR', 'Download all static content to directory'

  c.action do |args, options|


    if options.pullall then
      sol = MrMurano::File.new
      all = sol.list
      

    end
  end
end

#  vim: set ai et sw=2 ts=2 :
