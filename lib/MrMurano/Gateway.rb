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


    end

    class Resources < Base
      # TODO: CRUD Resources
      # - Create
      # - Read
      # - Update
      # - Delete

      def list()
        get('/getProduct')
      end

      # XXX We will want SyncUpDown on this one.
    end

    class Device < Base

      ## All devices (pagination?)
      def list
        # MRMUR-54
      end

      ## Get one device
      def fetch(id)
        # MRMUR-54
      end

      ## Create a device with given Identity
      def enable(id)
        # MRMUR-51
      end
      alias whitelist enable

      ## Create a bunch of devices at once
      # @param data [String] CSV of identifies to create
      #
      # The API wants CVS data. So is #data a string of CSV? or an array that we
      # convert into CSV for uploading?
      def enable_batch(data)
        # MRMUR-52
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :


