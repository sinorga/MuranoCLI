require 'uri'
require 'cgi'
require 'net/http'
require "http/form_data"
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SyncUpDown'

module MrMurano
  ## The details of talking to the Content service.
  module Content
    class Base
      def initialize
        @pid = $cfg['project.id']
        raise "No project id!" if @pid.nil?
        @uriparts = [:service, @pid, :content]
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

      # MRMUR-61, MRMUR-62
      def list
        get('/list')
      end

      # MRMUR-61, MRMUR-62
      def fetch(id)
      end

      # MRMUR-59
      def upload(id, local_path)
        # This is a two step process.
        # 1: Get the post instructions for S3.
        # 2: Upload to S3.
        ret = get("/upload?expires_in=3600&name=#{CGI.escape(id)}")
        debug "POST instructions: #{ret}"
        raise "Method isn't POST!!!" unless ret[:method] == 'POST'
        raise "EncType isn't multipart/form-data" unless ret[:enctype] == 'multipart/form-data'

        uri = URI(ret[:url])
        request = Net::HTTP::Post.new(uri)
        mime = MIME::Types.type_for(local_path.to_s)[0] || MIME::Types["application/octet-stream"][0]
        file = HTTP::FormData::File.new(local_path.to_s, {:mime_type=>mime})
        form = HTTP::FormData.create(ret[:inputs].merge({ret[:field]=>file}))

        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
        request.content_type = form.content_type
        request.content_length = form.content_length
        request.body = form.to_s

        if $cfg['tool.curldebug'] then
          a = []
          a << %{curl -s}
          a << %{-H 'User-Agent: #{request['User-Agent']}'}
          a << %{-X #{request.method}}
          a << %{'#{request.uri.to_s}'}
          ret[:inputs].each_pair do |key, value|
            a << %{-F '#{key}=#{value}'}
          end
          a << %{-F #{ret[:field]}=@#{local_path.to_s}}
          puts a.join(' ')
        end

        unless $cfg['tool.dry'] then
          response = http.request(request)
          case response
          when Net::HTTPSuccess
          else
            showHttpError(request, response)
          end
        end
      end

      # MRMUR-60
      def remove(id)
      end

      # MRMUR-59
      def download(id, &block)
        # This is a two step process.
        # 1: Get the get instructions for S3.
        # 2: fetch from S3.
        ret = get("/download?id=#{CGI.escape(id)}")
        debug "GET instructions: #{ret}"
        raise "Method isn't GET!!!" unless ret[:method] == 'GET'

        uri = URI(ret[:url])
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"

        if $cfg['tool.curldebug'] then
          a = []
          a << %{curl -s}
          a << %{-H 'User-Agent: #{request['User-Agent']}'}
          a << %{-X #{request.method}}
          a << %{'#{request.uri.to_s}'}
          puts a.join(' ')
        end

        unless $cfg['tool.dry'] then
          response = http.request(request)
          case response
          when Net::HTTPSuccess
            if block_given? then
              resp.read_body(&block)
            else
              resp.read_body do |chunk|
                $stdout.write chunk
              end
            end
          else
            showHttpError(request, response)
          end
        end
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :
