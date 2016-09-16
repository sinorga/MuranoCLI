require 'uri'
require 'net/http'
require 'json'
require 'date'
require 'pathname'
require 'yaml'
require 'MrMurano/Config'
require 'MrMurano/http'

module MrMurano
  class Passwords
    def initialize(path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      @path = path
      @data = nil
    end
    def load()
      if @path.exist? then
        @path.chmod(0600)
        @path.open('rb') do |io|
          @data = YAML.load(io)
        end
      end
    end
    def save()
      @path.open('wb') do |io|
        io << @data.to_yaml
      end
      @path.chmod(0600)
    end
    def set(host, user, pass)
      unless @data.kind_of? Hash then
        @data = {host=>{user=>pass}}
        return
      end
      hd = @data[host]
      if hd.nil? or not hd.kind_of?(Hash) then
        @data[host] = {user=>pass}
        return
      end
      @data[host][user] = pass
      return
    end
    def get(host, user)
      return nil unless @data.kind_of? Hash
      return nil unless @data.has_key? host
      return nil unless @data[host].kind_of? Hash
      return nil unless @data[host].has_key? user
      return @data[host][user]
    end
  end

  class Account
    include Http

    def endPoint(path)
      URI('https://' + $cfg['net.host'] + '/api:1/' + path.to_s)
    end

    def _loginInfo
      host = $cfg['net.host']
      user = $cfg['user.name']
      if user.nil? then
        user = ask("Account name: ")
        $cfg.set('user.name', user, :user)
      end
      pff = Pathname.new(ENV['HOME']) + '.mrmurano/passwords'
      pf = Passwords.new(pff)
      pf.load
      pws = pf.get(host, user)
      if pws.nil? then
        pws = ask("Password:  ") { |q| q.echo = "*" }
        pf.set(host, user, pws)
        pf.save
      end
      {
        :email => $cfg['user.name'],
        :password => pws
      }
    end

    # Store the token in a class variable so that we only fetch it once per run
    # session of this tool
    @@token = nil
    def token
      if @@token.nil? then
        # Cannot have token call token, so cannot use workit.
        uri = endPoint('token/')
        request = Net::HTTP::Post.new(uri)
        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
        request.content_type = 'application/json'
        curldebug(request)
        #request.basic_auth(username(), password())
        request.body = JSON.generate(_loginInfo)

        response = http.request(request)
        case response
        when Net::HTTPSuccess
          token = JSON.parse(response.body, json_opts)
          @@token = token[:token]
        else
          say_error "No token! because: #{response}"
          @@token = nil
          raise response
        end
      end
      @@token
    end

    def businesses
      get('user/' + $cfg['user.name'] + '/membership/')
    end

    def products
      raise "Missing Bussiness ID" if $cfg['business.id'].nil?
      get('business/' + $cfg['business.id'] + '/product/')
    end

    def solutions
      raise "Missing Bussiness ID" if $cfg['business.id'].nil?
      get('business/' + $cfg['business.id'] + '/solution/')
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
