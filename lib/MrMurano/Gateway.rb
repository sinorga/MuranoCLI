require 'uri'
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

      # XXX We will want SyncUpDown on this one.
    end

    ##
    # Talking to the devices on a Gateway
    class Device < Base
      def initialize
        super
        @uriparts << :device
      end

      ## All devices (pagination?)
      def list(limit=1000)
        # MRMUR-54
        get("?limit=#{limit}")
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
        # MRMUR-51
        put("/#{CGI.escape(id)}")
      end
      alias whitelist enable
      alias create enable

      ## Create a bunch of devices at once
      # @param data [String] CSV of identifies to create
      #
      # The API wants CVS data. So is #data a string of CSV? or an array that we
      # convert into CSV for uploading?
      def enable_batch(data)
        # MRMUR-52

        # multipart/form-data
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :


