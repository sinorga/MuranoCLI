require 'uri'
require 'net/http'
require 'net/http/post/multipart'
require 'json'
require 'yaml'
require 'date'
require 'digest/sha1'
require 'pp'

module MrMurano
  class SolutionBase
    def initialize
      @token = Account.new.token
      @sid = $cfg['solution.id']
      raise "No solution!" if @sid.nil?
      @uriparts = [:solution, @sid]
      @itemkey = 'id'
    end

    def verbose(msg)
      if $cfg['tool.verbose'] then
        say msg
      end
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

    def tolocalname(item, key)
      item[key]
    end

    def pull(into, overwrite=false)
      into = Pathname.new(into) unless into.kind_of? Pathname
      into.mkdir unless into.exist?
      raise "Not a directory: #{into.to_s}" unless into.directory?
      key = @itemkey.to_s

      there = list()
      there.each do |item|
        name = tolocalname(item, key)
        raise "Bad key(#{key}) for #{item}" if name.nil?
        dest = into + name

        if not dest.exist? or overwrite then
          verbose "Pulling #{item[key]} into #{dest.to_s}"
          if not $cfg['tool.dry'] then
            dest.open('wb') do |outio|
              fetch(item[key]) do |chunk|
                outio.write chunk
              end
            end
          end
        else
          verbose "Skipping #{item[key]} because it exists"
        end
      end
    end

  end
  class Solution < SolutionBase
    def version
      get('/version')
    end

    def info
      get()
    end

    # …/serviceconfig
    def sc # TODO understand this. (i think it has to do with getting data to flow)
      get('/serviceconfig/')
    end
  end

  # …/file 
  class File < SolutionBase
    def initialize
      super
      @uriparts << 'file'
      @itemkey = :path
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
            say_error resp.to_s
            raise resp
          end
        end
        nil
      end
    end

#    def push(local, remote, force=false)
#        sha1 = Digest::SHA1.file(local.to_s).hexdigest
#    end

    ##
    # Delete a file
    def remove(path)
      # TODO test
      delete('/'+path)
    end

    ##
    # Upload a file
    def upload(local, remote)
      local = Pathname.new(local) unless local.kind_of? Pathname

      mime=`file -I -b #{local.to_s}`
      mime='application/octect' if mime.nil?

      uri = endPoint('upload/' + remote)
      upper = UploadIO.new(File.new(localfile), mime, local.basename)
			req = Net::HTTP::Post::Multipart.new(uri, 'file'=> upper )
      workit(req)
    end

    def tolocalname(item, key)
      name = item[key]
      name = $cfg['files.default_page'] if name == '/'
      name
    end
  end

  # …/role
  class Role < SolutionBase
    def initialize
      super
      @uriparts << 'role'
      @itemkey = :role_id
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

    def pull(into, overwrite=false)
      into = Pathname.new(into) unless into.kind_of? Pathname
      #into.mkdir unless into.exist?
      raise "Not a file: #{into.to_s}" if into.exist? and not into.file?
      key = @itemkey.to_s

      there = list()

      if not into.exist? or overwrite then
        verbose "Pulling roles into #{into.to_s}"
        if not $cfg['tool.dry'] then
          into.open('wb') do |outio|
            outio.write there.to_yaml
          end
        end
      else
          verbose "Skipping roles because #{into.to_s} exists"
      end
    end
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

    def pull(into, overwrite=false)
      into = Pathname.new(into) unless into.kind_of? Pathname
      #into.mkdir unless into.exist?
      raise "Not a file: #{into.to_s}" if into.exist? and not into.file?
      key = @itemkey.to_s

      there = list()

      if not into.exist? or overwrite then
        verbose "Pulling users into #{into.to_s}"
        if not $cfg['tool.dry'] then
          into.open('wb') do |outio|
            outio.write there.to_yaml
          end
        end
      else
          verbose "Skipping users because #{into.to_s} exists"
      end
    end
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
      ret = get('/' + id.to_s)
      aheader = ret['script'].lines.first
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

    def tolocalname(item, key)
      name = item['method'].downcase
      name << '_'
      name << item['path'].gsub(/\//, '-')
      name << '.lua'
    end
  end

  # …/library
  class Library < SolutionBase
    def initialize
      super
      @uriparts << 'library'
      @itemkey = :alias
    end

    def mkalias(name)
      "/#{$cfg['solution.id']}_#{name}"
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
      # TODO Test this, I'm guesing.
      delete(mkalias(name))
    end

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

    def tolocalname(item, key)
      "#{item['name']}.lua"
    end
  end

  # …/eventhandler
  class EventHandler < SolutionBase
    def initialize
      super
      @uriparts << 'eventhandler'
      @itemkey = :alias
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

    def tolocalname(item, key)
      "#{item['name']}.lua"
    end
  end

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

    sol = MrMurano::Role.new
    say sol.list
    say sol.fetch('debug')

  end
end

command :pull do |c|
  c.syntax = %{mr pull}
  c.description = %{For a project, pull a copy of everything down.}
  c.option '--overwrite', 'Replace local files.'

  c.option '--all', 'Pull everything'
  c.option '--files', 'Pull static files down'
  c.option '--endpoints', 'Pull endpoints down'
  c.option '--modules', 'Pull modules down'
  c.option '--roles', 'Pull roles down'
  c.option '--users', 'Pull users down'
  c.option '--eventhandlers', 'Pull users down'

  c.action do |args, options|

    if options.all then
      options.files = true
      options.endpoints = true
      options.modules = true
      options.roles = true
      options.users = true
      options.eventhandlers = true
    end

    if options.files then
      sol = MrMurano::File.new
      sol.pull( $cfg['location.base'] + $cfg['location.files'], options.overwrite )
    end

    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.pull( $cfg['location.base'] + $cfg['location.endpoints'], options.overwrite )
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.pull( $cfg['location.base'] + $cfg['location.modules'], options.overwrite )
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.pull( $cfg['location.base'] + $cfg['location.roles'], options.overwrite )
    end

    if options.users then
      sol = MrMurano::User.new
      sol.pull( $cfg['location.base'] + $cfg['location.users'], options.overwrite )
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.pull( $cfg['location.base'] + $cfg['location.eventhandlers'], options.overwrite )
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
