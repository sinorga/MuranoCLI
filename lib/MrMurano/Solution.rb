require 'uri'
require 'net/http'
require 'json'
require 'date'
require 'pp'

module MrMurano
  class Solution
    def endPoint(path)
      URI('https://' + $cfg['net.host'] + '/api:1/solution/' +
          $cfg['solution.id'] + path.to_s)
    end

    def version
      r = endPoint('/version')
      Net::HTTP.start(r.host, r.port, :use_ssl=>true) do |http|
        request = Net::HTTP::Get.new(r)
        request.content_type = 'application/json'
        request['authorization'] = 'token ' + token

        response = http.request(request)
        case response
        when Net::HTTPSuccess
          busy = JSON.parse(response.body)
          return busy
        else
          raise response
        end
      end
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
