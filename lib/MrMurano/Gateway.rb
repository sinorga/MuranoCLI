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
      # MRMUR-58

      # TODO: CRUD Resources
      # - Create
      # - Read
      # - Update
      # - Delete

      def list()
        ret = get('')
        return {} unless ret.has_key? :resources
        ret[:resources]
      end

      def create_res(name, type, unit)
        # XXX This is a REPLACING action. So to *add* we have to read-modify-write.
        patch('/', {:resources=>{
          name => {
            :format => type,
            :unit => unit,
            :settable => true,
            #:allowed => [],
          }
        }
        })
      end


      # TODO We will want SyncUpDown on this one.
    end

    ##
    # Talking to the devices on a Gateway
    class Device < Base
      def initialize
        super
        @uriparts << :device
      end

      ## All devices (pagination?)
      def list(limit=nil, before=nil)
        # MRMUR-54
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

      # Call the device Activation URI.
      #
      # Only useful durring debugging of devices.
      #
      # @param identifier [String] Who to activate.
      def activate(identifier)
        fqdn = info()[:fqdn]
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

    end
  end
end

#  vim: set ai et sw=2 ts=2 :


