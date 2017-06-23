require 'uri'
require 'net/http'
require 'json'
require 'date'
require 'pathname'
require 'yaml'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'

module MrMurano
  class Passwords
    include Verbose
    def initialize(path=nil)
      path = $cfg.file_at('passwords', :user) if path.nil?
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
      if $cfg['tool.dry']
        say "--dry: Not saving config"
        return
      end
      @path.dirname.mkpath unless @path.dirname.exist?
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
      return ENV['MURANO_PASSWORD'] unless ENV['MURANO_PASSWORD'].nil?
      unless ENV['MR_PASSWORD'].nil? then
        warning %{Using depercated ENV "MR_PASSWORD", please rename to "MURANO_PASSWORD"}
        return ENV['MR_PASSWORD']
      end
      return nil unless @data.kind_of? Hash
      return nil unless @data.has_key? host
      return nil unless @data[host].kind_of? Hash
      return nil unless @data[host].has_key? user
      return @data[host][user]
    end

    ## Remove the password for a user
    def remove(host, user)
      if @data.kind_of? Hash then
        hd = @data[host]
        if not hd.nil? and hd.kind_of?(Hash) then
          if hd.has_key? user then
            @data[host].delete user
          end
        end
      end
    end

    ## Get all hosts and usernames. (does not return the passwords)
    def list
      ret = {}
      @data.each_pair{|key,value| ret[key] = value.keys} unless @data.nil?
      ret
    end
  end

  #------------------------------------------------------------------------

  class Account
    include Http
    include Verbose

    def endPoint(path)
      URI('https://' + $cfg['net.host'] + '/api:1/' + path.to_s)
    end

    def _loginInfo
      host = $cfg['net.host']
      user = $cfg['user.name']
      if user.nil? or user.empty? then
        error("No Murano user account found; please login")
        user = ask("User name: ")
        $cfg.set('user.name', user, :user)
      end
      pff = $cfg.file_at('passwords', :user)
      pf = Passwords.new(pff)
      pf.load
      pws = pf.get(host, user)
      if pws.nil? then
        error("Couldn't find password for #{user}")
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
          showHttpError(request, response)
          error "Check to see if username and password are correct."
          @@token = nil
        end
      end
      @@token
    end

    def token_reset(value=nil)
      @@token = value
    end

    def adc_compat_check
#      unless $cfg['business.id'].nil? then
#        unless has_projects?($cfg['business.id']) then
#          # This is 3.x which does not support projects!
#          warning('!'*80)
#          warning "Your business requires MuranoCLI 2.x"
#          warning "Some features may not work correctly."
#          warning('!'*80)
#        end
#      end
    end

    #------------------------------------------------------------------------

    def new_account(email, name, company="")
      post('key/', {
        :email=>email,
        :name=>name,
        :company=>company,
        :source=>'signup',
      })
    end

    def reset_account(email)
      post('key/', { :email=>email, :source=>'reset' })
    end

    def accept_account(token, password)
      post("key/#{token}", {:password=>password})
    end

    #------------------------------------------------------------------------

    def businesses
      _loginInfo if $cfg['user.name'].nil?
      get('user/' + $cfg['user.name'] + '/membership/')
    end

    def new_business(name)
      post('business/', {:name=>name})
    end

    def delete_business(id)
      delete("business/#{id}")
    end

    def overview(id=nil, &block)
      id = $cfg['business.id'] if id.nil?
      get("business/#{id}/overview", &block)
    end

    def has_projects?(id)
      ret = get("business/#{id}/overview")
      return false unless ret.kind_of? Hash
      return false unless ret.has_key? :tier
      tier = ret[:tier]
      return false unless tier.kind_of? Hash
      return false unless tier.has_key? :enableProjects
      return tier[:enableProjects]
    end

    # FIXME/2017-06-23/MAYBE: Find more commands that should call must_business_id!.
    MISSING_BUSINESS_ID_MSG = %{
Missing Business ID.
Call \`#{File.basename $PROGRAM_NAME} business list\` to get a list of BIZ_IDs.
Set the ID temporarily using --config business.id=<BIZ_ID>,
or permantently using \`#{File.basename $PROGRAM_NAME} config business.id <BIZ_ID>.
    }.strip
    def must_business_id!
      raise MrMurano::ConfigError.new(MISSING_BUSINESS_ID_MSG) if $cfg['business.id'].nil?
    end

    #------------------------------------------------------------------------

    #ALLOWED_TYPES = [:domain,:onepApi,:dataApi,:application,:product].freeze
    ALLOWED_TYPES = [:application,:product].freeze

    def solutions(type=:all, invalidate=false)
      debug "Getting all solutions of type #{type}"
      must_business_id!

      type = type.to_sym
      raise "Unknown type(#{type})" unless type == :all or ALLOWED_TYPES.include? type
      # Cache the result since sometimes both products() and applications() are called.
      if invalidate or !instance_variable_defined?("@bizSolns")
        got = get('business/' + $cfg['business.id'] + '/solution/')
        @bizSolns = got
      end
      solz = @bizSolns.dup
      unless type == :all
        solz.select!{|i| i[:type] == type.to_s}
      end
      solz
    end

    # SYNC_ME: See regex in bizapi: lib/api/route/business/solution.js
    #
    # NOTE: 2017-06-02: In bizapi, it's: /^?![0-9][a-zA-Z0-9]{1,63}$/
    #           but this code has been checking /^[a-zA-Z0-9]{0,62}$/
    #                      and [lb] is hesitant to change it to 63 now.
    #
    # FIXME: Allow uppercase once pegasus_registry fixed.
    #SOLN_NAME_REGEX = /^(?![0-9])[a-zA-Z0-9]{1,62}$/
    #SOLN_NAME_HELP = "Solution name must contain only letters and/or numbers"
    #
    # For now, lowercase only.
    SOLN_NAME_REGEX = /^(?![0-9])[a-z0-9]{1,62}$/
    SOLN_NAME_HELP = "Solution name must contain only lowercase letters and/or numbers,\nand the name may not start with a number"
    #
    # MUR-2454: Dashes no longer allowed in sol'n name
    # Legacy check (good old days, before soln name was also a Lua variable name):
    #SOLN_NAME_REGEX = /^[a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9]{0,1}|[a-zA-Z0-9]{0,62})$/
    #SOLN_NAME_HELP = "Solution name must be a valid domain name component"

    ## Create a new solution in the current business
    def new_solution(name, type)
      must_business_id!
      type = type.to_s.to_sym
      raise "Unknown type(#{type})" unless ALLOWED_TYPES.include? type
      # FIXME: Allow uppercase once pegasus_registry fixed.
      raise MrMurano::ConfigError.new(SOLN_NAME_HELP) unless name.match(SOLN_NAME_REGEX)
      if $cfg['tool.dry']
        say "--tag: Not creating solution #{name}"
        return nil
      end
      self.whirly_start "Creating solution..."
      resp = post('business/' + $cfg['business.id'] + '/solution/', {:label=>name, :type=>type})
      self.whirly_stop
      resp
    end

    def delete_solution(apiId)
      must_business_id!
      delete('business/' + $cfg['business.id'] + '/solution/' + apiId)
    end

    #------------------------------------------------------------------------

    def products
      solutions(:product)
    end

    ## Create a new product in the current business
    def new_product(name, type=:product)
      new_solution(name, type)
    end

    def delete_product(modelId)
      delete_solution(modelId)
    end

    #------------------------------------------------------------------------

    def applications
      solutions(:application)
    end

    ## Create a new application in the current business
    def new_application(name, type=:application)
      new_solution(name, type)
    end

    def delete_application(modelId)
      delete_solution(modelId)
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
