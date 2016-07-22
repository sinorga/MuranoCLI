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

    def toremotename(root, path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      root = Pathname.new(root) unless root.kind_of? Pathname
      path.relative_path_from(root).to_s
    end
    def tolocalpath(into, item)
      into.mkpath unless $cfg['tool.dry']
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
      key = @itemkey.to_sym
      item[key]
    end

    def syncup(from, options={})
      there = list()
      here = locallist(from)
      itemkey = @itemkey.to_sym
 
      # split into three lists.
      # - Items here and not there. (toadd)
      # - Items there and not here. (todel)
      # - Items here and there. (tomod)
      therebox = {}
      there.each do |item|
        item = Hash.transform_keys_to_symbols(item)
        therebox[ synckey(item) ] = item
      end
      herebox = {}
      here.each do |item|
        item = Hash.transform_keys_to_symbols(item)
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

    def syncdown(into, options={})
      there = list()
      into = Pathname.new(into) unless into.kind_of? Pathname
      here = locallist(into)
      itemkey = @itemkey.to_sym
 
      # split into three lists.
      # - Items here and not there. (todel)
      # - Items there and not here. (toadd)
      # - Items here and there. (tomod)
      therebox = {}
      there.each do |item|
        item = Hash.transform_keys_to_symbols(item)
        therebox[ synckey(item) ] = item
      end
      herebox = {}
      here.each do |item|
        item = Hash.transform_keys_to_symbols(item)
        herebox[ synckey(item) ] = item
      end
      todel = herebox.keys - therebox.keys
      toadd = therebox.keys - herebox.keys
      tomod = herebox.keys & therebox.keys

      if options.delete then
        todel.each do |key|
          verbose "Removing item #{key}"
          unless $cfg['tool.dry'] then
            item = herebox[key]
            dest = tolocalpath(into, item)
            removelocal(dest, item)
          end
        end
      end
      if options.create then
        toadd.each do |key|
          verbose "Adding item #{key}"
          unless $cfg['tool.dry'] then
            item = therebox[key]
            dest = tolocalpath(into, item)

            download(dest, item)
          end
        end
      end
      if options.update then
        tomod.each do |key|
          verbose "Updating item #{key}"
          unless $cfg['tool.dry'] then
            item = therebox[key]
            dest = tolocalpath(into, herebox[key].merge(item) )

            download(dest, item)
          end
        end
      end
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

    def status(from, options={})
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
          # FIXME what if therebox[key] is nil?
          :tomod=> tomod.map{|key| therebox[key].merge(herebox[key]) }
        }
      else
        toadd = herebox.keys - therebox.keys
        todel = therebox.keys - herebox.keys
        tomod = herebox.keys & therebox.keys
        {
          :toadd=> toadd.map{|key| herebox[key] },
          :todel=> todel.map{|key| therebox[key] },
          :tomod=> tomod.map{|key| therebox[key].merge(herebox[key]) }
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

    sol = MrMurano::File.new
    pp sol.list
    #pp sol.locallist($cfg['location.base'] + $cfg['location.endpoints'])
    #sol.syncup($cfg['location.base'] + $cfg['location.endpoints'])

  end
end

#  vim: set ai et sw=2 ts=2 :
