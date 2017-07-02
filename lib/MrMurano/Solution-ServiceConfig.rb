require 'MrMurano/Solution'

module MrMurano
  # …/serviceconfig
  class ServiceConfig < SolutionBase
    def initialize(sid)
      super
      @uriparts << 'serviceconfig'
      @scid = nil
    end

    def list(call=nil, data=nil, &block)
      ret = get(call, data, &block)
      return [] if ret.is_a?(Hash) and ret.has_key?(:error)
      ret[:items]
    end

    def search(svc_name)
      #path = nil
      #path = "?select=id,service,script_key"
      # 2017-07-02: This is what yeti-ui adds.
      # FIXME/EXPLAIN/2017-07-02: What's "UUID" that web UI uses?
      path = "?select=service,id,solution_id,script_key,alias"
      super(svc_name, path)
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    def scid_for_name(name)
      name = name.to_s unless name.kind_of? String
      scr = list().select{|i| i[:service] == name}.first
      return nil if scr.nil?
      scr[:id]
    end

    def scid
      return @scid unless @scid.nil?
      @scid = scid_for_name(@serviceName)
    end

    def create(pid, name=nil, &block) #? script_key?
      name = pid if name.nil?
      # See pegasus_registry PostServiceConfig for the POST properties.
      #   pegasus_registry/api/swagger/paths/serviceconfig.yaml
      #   pegasus_registry/api/swagger/definitions/serviceconfig.yaml
      post('/', {
        :solution_id => @sid,
        :service => pid,
        # 2017-06-26: "name" seems to work, but "script_key" is what web UI uses.
        #   See yeti-ui/bridge/src/js/api/services.js::linkApplicationService
        #:name => name,
        :script_key => name,
      }, &block)
    end

    def remove(id)
      delete("/#{id}")
    end

    def info(id=scid)
      get("/#{id}/info")
    end

    def logs(id=scid)
      get("/#{id}/logs")
    end

    def call(opid, meth=:get, data=nil, id=scid, &block)
      raise "Service '#{@serviceName}' not enabled for this Solution" if id.nil?
      call = "/#{id.to_s}/call/#{opid.to_s}"
      debug "Will call: #{call}"
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
        delete(call, &block)
      else
        raise "Unknown method: #{meth}"
      end
    end
  end

  ## This is only used for debugging and deciphering APIs.
  #
  # There was once a plan for using this to automagically map commands into
  # services by reading their schema.  That plan had too much magic and was too
  # fragile for real use.
  #
  # A much better UI/UX happens with human intervention.
  # :nocov:
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
      ret = get
      return [] if ret.is_a?(Hash) and ret.has_key?(:error)
      ret[:items]
    end

    def schema(id=sid)
      # TODO: cache schema in user dir?
      get("/#{id}/schema")
    end

    ## Get list of call operations from a schema
    def callable(id=sid, all=false)
      scm = schema(id)
      calls = []
      scm[:paths].each do |path, methods|
        methods.each do |method, params|
          if params.kind_of?(Hash) then
            call = [method]
            call << path.to_s if all
            call << params[:operationId]
            call << (params['x-internal-use'.to_sym] or false) if all
            calls << call
          end
        end
      end
      calls
    end
  end
  # :nocov:
end

#  vim: set ai et sw=2 ts=2 :

