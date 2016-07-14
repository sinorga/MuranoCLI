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
    # This might also be a valid ProductBase.
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
          return {} if response.body.nil?
          begin
            return JSON.parse(response.body)
          rescue
            return response.body
          end
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
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

    def put(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Put.new(uri)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def delete(path='', &block)
      uri = endPoint(path)
      workit(Net::HTTP::Delete.new(uri), &block)
    end

    # …

    def tolocalname(item, key)
      item[key]
      # should this return a Pathname instead?
    end

    def toremotename(root, path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      root = Pathname.new(root) unless root.kind_of? Pathname
      path.relative_path_from(root).to_s
    end

    def locallist(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      unless from.exist? then
        return []
      end
      raise "Not a directory: #{from.to_s}" unless from.directory?

      Pathname.glob(from.to_s + '/**/*').map do |path|
        name = toremotename(from, path)
        case name
        when Hash
          name[:local_path] = path
          name
        else
          {:local_path => path, :name => name}
        end
      end
    end

    def synckey(item)
      key = @itemkey.to_s
      item[key]
    end

    def syncup(from, options={})
      there = list()
      here = locallist(from)
      itemkey = @itemkey.to_s
 
      # split into three lists.
      # - Items here and not there. (toadd)
      # - Items there and not here. (todel)
      # - Items here and there. (tomod)
      therebox = {}
      there.each do |item|
        therebox[ synckey(item) ] = item
      end
      herebox = {}
      here.each do |item|
        herebox[ synckey(item) ] = item
      end
      toadd = herebox.keys - therebox.keys
      todel = therebox.keys - herebox.keys
      tomod = herebox.keys & therebox.keys

      if options.delete then
        todel.each do |key|
          verbose "Removing item #{key}"
          unless $cfg['tool.dry'] then
            item = therebox[key]
            remove(item[itemkey])
          end
        end
      end
      if options.create then
        toadd.each do |key|
          verbose "Adding item #{key}"
          unless $cfg['tool.dry'] then
            item = herebox[key]
            upload(item[:local_path], item.reject{|k,v| k==:local_path})
          end
        end
      end
      if options.update then
        tomod.each do |key|
          verbose "Updating item #{key}"
          unless $cfg['tool.dry'] then
            #item = therebox[key].merge herebox[key] # need to be consistent with key types for this to work
            id = therebox[key][itemkey]
            item = herebox[key].dup
            item[itemkey] = id
            upload(item[:local_path], item.reject{|k,v| k==:local_path})
          end
        end
      end
    end

    # TODO sync down: like pull, but deletes local things not remote
    def syncdown(into, options={})
      there = list()
      into = Pathname.new(into) unless into.kind_of? Pathname
      here = locallist(into)
      itemkey = @itemkey.to_s
 
      # split into three lists.
      # - Items here and not there. (todel)
      # - Items there and not here. (toadd)
      # - Items here and there. (tomod)
      therebox = {}
      there.each do |item|
        therebox[ synckey(item) ] = item
      end
      herebox = {}
      here.each do |item|
        herebox[ synckey(item) ] = item
      end
      todel = herebox.keys - therebox.keys
      toadd = therebox.keys - herebox.keys
      tomod = herebox.keys & therebox.keys

      if options.delete then
        todel.each do |key|
          verbose "Removing item #{key}"
          unless $cfg['tool.dry'] then
            say_error "NOT IMPLEMENTED YET"
          end
        end
      end
      if options.create then
        into.mkpath unless $cfg['tool.dry']
        toadd.each do |key|
          verbose "Adding item #{key}"
          unless $cfg['tool.dry'] then
            item = therebox[key]
            name = tolocalname(item, itemkey)
            raise "Bad key(#{itemkey}) for #{item}" if name.nil?
            dest = into + name

            download(dest, item)
          end
        end
      end
      if options.update then
        into.mkpath unless $cfg['tool.dry']
        tomod.each do |key|
          verbose "Updating item #{key}"
          unless $cfg['tool.dry'] then
            dest = herebox[key][:local_path]
            item = therebox[key]

            download(dest, item)
          end
        end
      end
    end

    def download(local, item)
      id = item[@itemkey.to_s]
      local.open('wb') do |io| # FIXME will fail for role/user
        fetch(id) do |chunk|
          io.write chunk
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

    def list
      get('/')
    end

    def log
      get('/logs')
    end

  end

  # …/serviceconfig
  class ServiceConfig < SolutionBase
    def initialize
      super
      @uriparts << 'serviceconfig'
    end

    def list
      get()['items']
    end
    def fetch(id)
      get('/' + id.to_s)
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
      get(path) do |request, http|
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
            say_error "got #{resp.to_s} from #{request} #{request.uri.to_s}"
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
    def upload(local, remote)
      local = Pathname.new(local) unless local.kind_of? Pathname

      # FIXME: bad request? why?
      uri = endPoint('upload' + remote[:path])
      upper = UploadIO.new(local.open('rb'), remote[:mime_type], local.basename)
			req = Net::HTTP::Put::Multipart.new(uri, 'file'=> upper )
      workit(req) do |request,http|
        request.delete 'Content-Type'

        response = http.request(request)
        case response
        when Net::HTTPSuccess
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
        end
      end
    end

    def tolocalname(item, key)
      name = item[key]
      name = $cfg['files.default_page'] if name == '/'
      name
    end

    def toremotename(from, path)
      name = super(from, path)
      name = '/' if name == $cfg['files.default_page']

      mime=`file -I -b #{path.to_s}`.chomp.sub(/;.*$/, '')
      mime='application/octect' if mime.nil?

      sha1 = Digest::SHA1.file(path.to_s).hexdigest

      {:path=>name, :mime_type=>mime, :checksum=>sha1}
    end

    def synckey(item)
      if item.has_key? :path then
        "#{item[:path]}_#{item[:checksum]}_#{item[:mime_type]}"
      else
        "#{item['path']}_#{item['checksum']}_#{item['mime_type']}"
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
      put('/' + remote[@itemkey.to_s], remote) do |request, http|
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
      name = item['method'].downcase
      name << '_'
      name << item['path'].gsub(/\//, '-')
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
      if item.has_key? :method then
        "#{item[:method]}_#{item[:path]}"
      else
        "#{item['method']}_#{item['path']}"
      end
    end

  end

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

    def tolocalname(item, key)
      name = item['name']
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
      if item.has_key? :name then
        item[:name]
      else
        item['name']
      end
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
      "#{item['name']}.lua"
    end

    def toremotename(from, path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      aheader = path.readlines().first
      md = /--#EVENT (\S+) (\S+)/.match(aheader)
      raise "Not an Event handler: #{path.to_s}" if md.nil?
      {:service=>md[1], :event=>md[2]}
    end

    def synckey(item)
      if item.has_key? :service then
        "#{item[:service]}_#{item[:event]}"
      else
        "#{item['service']}_#{item['event']}"
      end
    end
  end

  # How do we enable product.id to flow into the eventhandler?

  ##
  # User Management common things
  class UserBase < SolutionBase
    def list()
      get()
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    def remove(id)
      delete('/' + id.to_s)
    end

    def upload(local, remote)
      # Roles cannot be modified, so must delete and post.
      delete('/' + remote[@itemkey.to_s]) do |request, http|
        response = http.request(request)
        case response
        when Net::HTTPSuccess
        when Net::HTTPNotFound
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
        end
      end
      post('/', remote)
    end

    # Since this works form a single file, needs different code.
    # This currently assumes that #list gets all of the info, and that we dno't
    # need to call #fetch on each item.
    def pull(into, overwrite=false)
      into = Pathname.new(into) unless into.kind_of? Pathname
      #into.mkdir unless into.exist?
      raise "Not a file: #{into.to_s}" if into.exist? and not into.file?
      key = @itemkey.to_s

      there = list()

      if not into.exist? or overwrite then
        verbose "Pulling #{self.class.to_s} into #{into.to_s}"
        if not $cfg['tool.dry'] then
          into.open('wb') do |outio|
            outio.write there.to_yaml
          end
        end
      else
          verbose "Skipping #{self.class.to_s} because #{into.to_s} exists"
      end
    end

    def locallist(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      if not from.exist? then
        say_warning "Skipping missing #{from.to_s}"
        return []
      end
      unless from.file? then
        say_warning "Cannot read from #{from.to_s}"
        return []
      end
      key = @itemkey.to_s

      here = {}
      from.open {|io| here = YAML.load(io) }
      
      here
    end
  end

  # …/role
  class Role < UserBase
    def initialize
      super
      @uriparts << 'role'
      @itemkey = :role_id
    end
  end

  # …/user
  class User < UserBase
    def initialize
      super
      @uriparts << 'user'
    end

    def upload(local, remote)
      say_warning "Updating Users isn't working currently."
      # post does work if the :password field is set.
    end

    def synckey(item)
      if item.has_key? :email then
        item[:email]
      else
        item['email']
      end
    end
  end

end

# I think what I want for top level commands is a 
# - sync --down : Make working dir like servers
#   --no-delete : Don't delete things at destination
#   --no-create : Don't create things at destination
#   --no-update : Don't update things at destination
# 
# And then various specific commands.
# fe: mr file here there to upload a single file
#     mr file --pull there here
#
command :sol do |c|
  c.syntax = %{mr solution ...}
  c.description = %{debug junk; please ignore}

  c.action do |args, options|

    sol = MrMurano::Endpoint.new
    pp sol.fetch('4JxZBgHmUO')
    #pp sol.list
    #pp sol.locallist($cfg['location.base'] + $cfg['location.endpoints'])
    #sol.syncup($cfg['location.base'] + $cfg['location.endpoints'])

  end
end

command :syncdown do |c|
  c.syntax = %{mr syncdown [options]}
  c.description = %{Sync project down from Murano}
  c.option '--endpoints', %{Sync Endpoints}
  c.option '--modules', %{Sync Modules}
  c.option '--eventhandlers', %{Sync Event Handlers}

  c.option '--files', %{Sync Static Files}

  c.option '--[no-]delete', %{Don't delete things from server}
  c.option '--[no-]create', %{Don't create things on server}
  c.option '--[no-]update', %{Don't update things on server}

  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true

    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.syncdown($cfg['location.base'] + $cfg['location.endpoints'], options)
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.modules'], options)
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.eventhandlers'], options)
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.roles'], options)
    end

    if options.users then
      sol = MrMurano::User.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.users'], options)
    end

    if options.files then
      sol = MrMurano::File.new
      sol.syncdown( $cfg['location.base'] + $cfg['location.files'], options)
    end

  end
end

command :syncup do |c|
  c.syntax = %{mr syncup [options]}
  c.description = %{Sync project up into Murano}
  c.option '--all', 'Sync everything'
  c.option '--endpoints', %{Sync Endpoints}
  c.option '--modules', %{Sync Modules}
  c.option '--eventhandlers', %{Sync Event Handlers}
  c.option '--roles', %{Sync Roles}
  c.option '--users', %{Sync Users}
  c.option '--files', %{Sync Static Files}

  c.option '--[no-]delete', %{Don't delete things from server}
  c.option '--[no-]create', %{Don't create things on server}
  c.option '--[no-]update', %{Don't update things on server}

  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true

    if options.all then
      options.files = true
      options.endpoints = true
      options.modules = true
      options.roles = true
      options.users = true
      options.eventhandlers = true
    end

    if options.endpoints then
      sol = MrMurano::Endpoint.new
      sol.syncup($cfg['location.base'] + $cfg['location.endpoints'], options)
    end

    if options.modules then
      sol = MrMurano::Library.new
      sol.syncup( $cfg['location.base'] + $cfg['location.modules'], options)
    end

    if options.eventhandlers then
      sol = MrMurano::EventHandler.new
      sol.syncup( $cfg['location.base'] + $cfg['location.eventhandlers'], options)
    end

    if options.roles then
      sol = MrMurano::Role.new
      sol.syncup( $cfg['location.base'] + $cfg['location.roles'], options)
    end

    if options.users then
      sol = MrMurano::User.new
      sol.syncup( $cfg['location.base'] + $cfg['location.users'], options)
    end

    if options.files then
      sol = MrMurano::File.new
      sol.syncup( $cfg['location.base'] + $cfg['location.files'], options)
    end

  end
end
alias_command :push, :syncup, '--no-delete'

#  vim: set ai et sw=2 ts=2 :
