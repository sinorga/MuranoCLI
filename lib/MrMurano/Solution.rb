require 'uri'
require 'net/http'
require 'json'
require 'pp'

module MrMurano
  class SolutionBase
    # This might also be a valid ProductBase.
    def initialize
      @token = Account.new.token
      @sid = $cfg['solution.id']
      raise "No solution!" if @sid.nil?
      @uriparts = [:solution, @sid]
      @itemkey = :id
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
      request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
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

    ##
    # Compute a remote resource name from the local path
    # @param root Pathname: Root path for this resource type from config files
    # @param path Pathname: Path to local item 
    # @return String: remote resource name
    def toremotename(root, path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      root = Pathname.new(root) unless root.kind_of? Pathname
      path.relative_path_from(root).to_s
    end

    ##
    # Compute the local name from remote item details
    # @param item Hash: listing details for the item.
    # @param itemkey Symbol: Key for look up.
    def tolocalname(item, itemkey)
      item[itemkey]
    end

    ##
    # Compute the local path from the listing details
    # 
    # If there is already a matching local item, some of its details are also in
    # the item hash.
    #
    # @param into Pathname: Root path for this resource type from config files
    # @param item Hash: listing details for the item.
    # @return Pathname: path to save (or merge) remote item into
    def tolocalpath(into, item)
      return item[:local_path] if item.has_key? :local_path
      itemkey = @itemkey.to_sym
      name = tolocalname(item, itemkey)
      raise "Bad key(#{itemkey}) for #{item}" if name.nil?
      dest = into + name
    end

    def locallist(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      unless from.exist? then
        return []
      end
      raise "Not a directory: #{from.to_s}" unless from.directory?

      from.children.map do |path|
        if path.directory? then
          # TODO: look for definition. ( ?.rockspec? ?mr.modules? ?mr.manifest? )
          # Lacking definition, find all *.lua but not *_test.lua
          # This specifically and intentionally only goes one level deep.
          path.children
        else
          path
        end
      end.flatten.compact.reject do |path|
        path.fnmatch('*_test.lua') or path.basename.fnmatch('.*')
      end.select do |path|
        path.extname == '.lua'
      end.map do |path|
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
      key = @itemkey.to_sym
      item[key]
    end

    def download(local, item)
      id = item[@itemkey.to_sym]
      local.open('wb') do |io|
        fetch(id) do |chunk|
          io.write chunk
        end
      end
    end

    def removelocal(dest, item)
      dest.unlink
    end

    def syncup(from, options=Commander::Command::Options.new)
      itemkey = @itemkey.to_sym
      options.asdown=false
      dt = status(from, options)
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options.delete then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            remove(item[itemkey])
          end
        end
      end
      if options.create then
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path})
          end
        end
      end
      if options.update then
        tomod.each do |item|
          verbose "Updating item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path})
          end
        end
      end
    end

    def syncdown(into, options=Commander::Command::Options.new)
      options.asdown = true
      dt = status(into, options)
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options.delete then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            removelocal(dest, item)
          end
        end
      end
      if options.create then
        into.mkpath unless $cfg['tool.dry']
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            download(dest, item)
          end
        end
      end
      if options.update then
        into.mkpath unless $cfg['tool.dry']
        tomod.each do |item|
          verbose "Updating item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, herebox[key].merge(item) )
            download(dest, item)
          end
        end
      end
    end

    def status(from, options=Commander::Command::Options.new)
      there = list()
      here = locallist(from)
      itemkey = @itemkey.to_sym
 
      therebox = {}
      there.each do |item|
        item = Hash.transform_keys_to_symbols(item)
        item[:synckey] = synckey(item)
        therebox[ item[:synckey] ] = item
      end
      herebox = {}
      here.each do |item|
        item = Hash.transform_keys_to_symbols(item)
        item[:synckey] = synckey(item)
        herebox[ item[:synckey] ] = item
      end
      if options.asdown then
        todel = herebox.keys - therebox.keys
        toadd = therebox.keys - herebox.keys
        tomod = herebox.keys & therebox.keys
        {
          :toadd=> toadd.map{|key| therebox[key] },
          :todel=> todel.map{|key| herebox[key] },
          :tomod=> tomod.map{|key|
            raise "Impossible modify" if therebox[key].nil?
            # Want here to override there except for itemkey.
            mrg = herebox[key].reject{|k,v| k==itemkey}
            therebox[key].merge(mrg)
          }
        }
      else
        toadd = herebox.keys - therebox.keys
        todel = therebox.keys - herebox.keys
        tomod = herebox.keys & therebox.keys
        {
          :toadd=> toadd.map{|key| herebox[key] },
          :todel=> todel.map{|key| therebox[key] },
          :tomod=> tomod.map{|key|
            raise "Impossible modify" if therebox[key].nil?
            # Want here to override there except for itemkey.
            mrg = herebox[key].reject{|k,v| k==itemkey}
            therebox[key].merge(mrg)
          }
        }
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

end

# And then various specific commands.
# fe: mr file here there to upload a single file
#     mr file --pull there here
#
command :sol do |c|
  c.syntax = %{mr solution ...}
  c.description = %{debug junk; please ignore}

  c.action do |args, options|

    sol = MrMurano::Endpoint.new
    #pp sol.list
    #pp sol.locallist($cfg['location.base'] + $cfg['location.endpoints'])
    #sol.syncup($cfg['location.base'] + $cfg['location.endpoints'])

  end
end

#  vim: set ai et sw=2 ts=2 :
