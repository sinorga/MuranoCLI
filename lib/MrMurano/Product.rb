require 'uri'
require 'net/http'
require 'json'
require 'tempfile'
require 'shellwords'
require 'pp'

module MrMurano
  class Product
    def initialize
      @pid = $cfg['product.id']
      raise "No Product ID!" if @pid.nil?
      @uriparts = [:project, @pid]
    end

    include Http

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

    ####…………

    def info
      get('info')
    end

    def list(offset=0, limit=50)
      get('device/')
    end

    def enable(sn)
      post("device/#{sn}")
    end

    def update(specFile)
      post('definition') do |http,request|
      end
    end

    def write(sn, values)
      post("write/#{sn}", values)
    end

    def provisioingProxey(foo)
      post("/proxy/provision/#{foo}")
    end
  end

end
#  vim: set ai et sw=2 ts=2 :
