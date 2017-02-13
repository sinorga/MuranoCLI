require 'uri'
require 'net/http'
require 'http/form_data'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SyncUpDown'

module MrMurano
  ## The details of talking to the Gateway service.
  # This where interfacing to real hardware happens.
  module Gateway
    class Base
      def initialize
        @pid = $cfg['project.id']
        raise "No project id!" if @pid.nil?
        @uriparts = [:service, @pid, :gateway]
        @itemkey = :id
        @locationbase = $cfg['location.base']
        @location = nil
      end

      include Http
      include Verbose

      ## Generate an endpoint in Murano
      # Uses the uriparts and path
      # @param path String: any additional parts for the URI
      # @return URI: The full URI for this enpoint.
      def endPoint(path='')
        parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
        s = parts.map{|v| v.to_s}.join('/')
        URI(s + path.to_s)
      end
      # …
      #include SyncUpDown

      def info
        get()
      end

    end

    class Resources < Base
      include SyncUpDown
      def initialize
        super
        @itemkey = :alias
        @location = 'resources.yaml'
      end
      # MRMUR-58

      # TODO: CRUD Resources
      # - Create
      # - Read
      # - Update
      # - Delete

      def list()
        ret = get('')
        return [] unless ret.has_key? :resources

        # convert hash to array.
        res = []
        ret[:resources].each_pair do |key, value|
          res << value.merge({:alias=>key.to_s})
        end
        res
      end

      def upload_all(data)
        # convert array to hash
        res = {}
        data.each do |value|
          key = value[:alias]
          res[key] = value.reject{|k,v| k==:alias}
        end

        patch('/', {:resources=>res})
      end

      def create_res(name, type, unit)
        # XXX This is a REPLACING action. So to *add* we have to read-modify-write.
        patch('/', {:resources=>{
          name => {
            :format => type,
            :unit => unit,
            :settable => true,
            #:allowed => [],
          },
          'fuzz' => {
            :format => type,
            :unit => unit,
            :settable => true,
            #:allowed => [],
          }
        }
        })
      end



      # TODO We will want SyncUpDown on this one.
      # But this one is differnet. Both sides are single-file, single-action.

      ###################################################
      def syncup_before()
        @there = list()
      end

      def remove(itemkey)
      end

      def upload(local, remote, modify)
      end

      def syncup_after()
        upload_all(@there)
        @there = nil
      end

      ###################################################
      def syncdown_before(local)
        @here = locallist()
      end

      def download(local, item)
        # needs to append/merge with file
        @here.delete_if do |i|
          i[@itemkey] == item[@itemkey]
        end
        @here << item.reject{|k,v| k==:synckey}
      end

      def removelocal(local, item)
        # needs to append/merge with file
        key = @itemkey.to_sym
        @here.delete_if do |it|
          it[key] == item[key]
        end
      end

      def syncdown_after(local)
        local.open('wb') do|io|
          # convert array to hash
          res = {}
          @here.each do |value|
            key = value[:alias]
            res[key] = Hash.transform_keys_to_strings(value.reject{|k,v| k==:alias})
          end
          io.write res.to_yaml
        end
        @here = nil
      end

      ###################################################
      def tolocalpath(into, item)
        into
      end

      def localitems(from)
        from = Pathname.new(from) unless from.kind_of? Pathname
        if not from.exist? then
          warning "Skipping missing #{from.to_s}"
          return []
        end
        unless from.file? then
          warning "Cannot read from #{from.to_s}"
          return []
        end

        here = {}
        from.open {|io| here = YAML.load(io) }
        here = {} if here == false

        res = []
        here.each_pair do |key, value|
          res << Hash.transform_keys_to_symbols(value).merge({:alias=>key.to_s})
        end
        res
      end

    end
    SyncRoot.add('resources', Resources, 'T', %{Resources.})

    ##
    # Talking to the devices on a Gateway
    class Device < Base
      def initialize
        super
        @uriparts << :device
      end

      ## All devices (pagination?)
      def list(limit=nil, before=nil)
        pr = {}
        pr[:limit] = limit unless limit.nil?
        pr[:before] = before unless before.nil?
        pr = nil if pr.empty?
        get('', pr)
      end

      def query(args)
        # ?limit=#
        # ?before=<time stamp in ms>
        # ?status={whitelisted, provisioned, locked, devmode, reprovision}
        # ?identity=<pattern>
        # ?ipaddress=<pattern>
        # ?version=<pattern>
      end

      ## Get one device
      # @param id [String] The identity to fetch
      def fetch(id)
        # MRMUR-54
        get("/#{CGI.escape(id)}")
      end

      ## Create a device with given Identity
      # @param id [String] The new identity
      def enable(id)
        put("/#{CGI.escape(id)}")
      end
      alias whitelist enable
      alias create enable

      ## Create a bunch of devices at once
      # @param local [String, Pathname] CSV file of identifiers
      # @param expire [Number] Expire time for all identities (ignored)
      def enable_batch(local, expire=nil)
        # MRMUR-52
        uri = endPoint('s/')
        file = HTTP::FormData::File.new(local.to_s, {:mime_type=>'text/csv'})
        form = HTTP::FormData.create(:identities=>file)
        req = Net::HTTP::Put.new(uri)
        set_def_headers(req)
        workit(req) do |request,http|
          request.content_type = form.content_type
          request.content_length = form.content_length
          request.body = form.to_s

          if $cfg['tool.curldebug'] then
            a = []
            a << %{curl -s -H 'Authorization: #{request['authorization']}'}
            a << %{-H 'User-Agent: #{request['User-Agent']}'}
            a << %{-X #{request.method}}
            a << %{'#{request.uri.to_s}'}
            a << %{-F identities=@#{local.to_s}}
            puts a.join(' ')
          end

          response = http.request(request)
          case response
          when Net::HTTPSuccess
          else
            showHttpError(request, response)
          end
        end
      end

      ## Delete a device
      def remove(identifier)
        delete("/#{CGI.escape(identifier)}")
      end

      # Call the device Activation URI.
      #
      # Only useful durring debugging of devices.
      #
      # @param identifier [String] Who to activate.
      def activate(identifier)
        fqdn = info()[:fqdn] # FIXME needs to call Base NOT self.
        fqdn = "#{@pid}.m2.exosite-staging.io" if fqdn.nil?

        uri = URI("https://#{fqdn}/provision/activate")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.start
        request = Net::HTTP::Post.new(uri)
        request.form_data = {
          :vendor => @pid,
          :model => @pid,
          :sn => identifier
        }
        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
        request['Authorization'] = nil
        request.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
        curldebug(request)
        response = http.request(request)
        case response
        when Net::HTTPSuccess
          return response.body
        else
          showHttpError(request, response)
        end
      end

      # Read & write resources.


      # Read & write State.

      def write(identifier, *args)

        put("/#{identifier}/state", {'bob'=>'fuddle'})
        # XXX fails with 404: Could not find entry
      end

      def read(identifier)
        get("/#{identifier}/state")
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :


