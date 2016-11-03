require 'MrMurano/Solution'

module MrMurano
  # …/serviceconfig
  class ServiceConfig < SolutionBase
    def initialize
      super
      @uriparts << 'serviceconfig'
    end

    def list
      get()[:items]
    end
    def fetch(id)
      get('/' + id.to_s)
    end

    def scid_for_name(name)
      name = name.to_s unless name.kind_of? String
      scr = list().select{|i| i[:service] == name}.first
      scr[:id]
    end

    def scid
      return @scid unless @scid.nil?
      @scid = scid_for_name(@serviceName)
    end

    def info(id=scid)
      get("/#{id}/info")
    end

    def logs(id=scid)
      get("/#{id}/logs")
    end

    def call(opid, meth=:get, data=nil, id=scid, &block)
      call = "/#{id.to_s}/call/#{opid.to_s}"
      case meth
      when :get
        get(call, data, &block)
      when :post
        data = {} if data.nil?
        post(call, data, &block)
      when :put
        data = {} if data.nil?
        put(call, data, &block)
      when :delete
        put(call, &block)
      end
    end

  end

  class Services < SolutionBase
    def initialize
      super
      @uriparts << 'service'
    end

    def sid_for_name(name)
      name = name.to_s unless name.kind_of? String
      scr = list().select{|i| i[:alias] == name}.first
      scr[:id]
    end

    def sid
      return @sid unless @sid.nil?
      @sid = sid_for_name(@serviceName)
    end

    def list
      ret = get()
      ret[:items]
    end

    def schema(id=sid)
      # TODO: cache schema in user dir?
      get("/#{id}/schema")
    end

    ## Get list of call operations from a schema
    def callable(id=sid)
      scm = schema(id)
      calls = []
      scm[:paths].each do |path, methods|
        methods.each do |method, params|
          if params.kind_of?(Hash) and
              not params['x-internal-use'.to_sym] and
              params.has_key?(:operationId) then
            calls << [method, params[:operationId]]
          end
        end
      end
      calls
    end
  end


  class SC_Device < ServiceConfig
    def initialize
      super
      @serviceName = 'device'
    end

    def assignTriggers(products)
      details = fetch(scid)
      products = [products] unless products.kind_of? Array
      details[:triggers] = {:pid=>products, :vendor=>products}

      put('/'+scid, details)
    end

    def showTriggers
      details = fetch(scid)

      return [] if details[:triggers].nil?
      details[:triggers][:pid]
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
