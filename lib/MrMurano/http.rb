require 'uri'
require 'net/http'
require 'json'

module MrMurano
  module Http
    def token
      return @token unless @token.nil?
      @token = Account.new.token
      raise "Not logged in!" if @token.nil?
      @token
    end

    def json_opts
      return @json_opts unless @json_opts.nil?
      @json_opts = {
        :allow_nan => true,
        :symbolize_names => true,
        :create_additions => false
      }
    end

    def curldebug(request)
      if $cfg['tool.curldebug'] then
        a = []
        a << %{curl -s -H 'Authorization: #{request['authorization']}'}
        a << %{-H 'User-Agent: #{request['User-Agent']}'}
        a << %{-H 'Content-Type: #{request.content_type}'}
        a << %{-X #{request.method}}
        a << %{'#{request.uri.to_s}'}
        a << %{-d '#{request.body}'} unless request.body.nil?
        puts a.join(' ')
      end
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

    def set_def_headers(request)
      request.content_type = 'application/json'
      request['authorization'] = 'token ' + token
      request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
      request
    end

    def workit(request, &block)
      curldebug(request)
      if block_given? then
        yield request, http()
      else
        response = http().request(request)
        case response
        when Net::HTTPSuccess
          return {} if response.body.nil?
          begin
            return JSON.parse(response.body, json_opts)
          rescue
            return response.body
          end
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
          say_error '==='
          raise response
        end
      end
    end

    def get(path='', &block)
      uri = endPoint(path)
      workit(set_def_headers(Net::HTTP::Get.new(uri)), &block)
    end

    def post(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Post.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def postf(path='', form={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Post.new(uri)
      set_def_headers(req)
      req.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
      req.form_data = form
      workit(req, &block)
    end

    def put(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Put.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def delete(path='', &block)
      uri = endPoint(path)
      workit(set_def_headers(Net::HTTP::Delete.new(uri)), &block)
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
