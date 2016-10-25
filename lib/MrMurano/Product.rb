require 'uri'
require 'mime/types'
require 'csv'
require 'pp'
require 'MrMurano/http'
require 'MrMurano/verbosing'

module MrMurano
  class ProductBase
    def initialize
      @pid = $cfg['product.id']
      raise "No Product ID!" if @pid.nil?
      @uriparts = [:product, @pid]
    end

    include Http
    include Verbose

    def endPoint(path='')
      parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
      s = parts.map{|v| v.to_s}.join('/')
      URI(s + path.to_s)
    end
  end

  class Product < ProductBase
    ## Get info about the product
    def info
      get('/info')
    end

    ## List enabled devices
    def list(offset=0, limit=50)
      get("/device/?offset=#{offset}&limit=#{limit}")
    end

    ## Enable a serial number
    # This creates the device and opens the activation window.
    def enable(sn)
      post("/device/#{sn.to_s}")
    end

    ## Upload a spec file.
    #
    # Note that this will fail if any of the resources already exist.
    def update(specFile)
      specFile = Pathname.new(specFile) unless specFile.kind_of? Pathname

      uri = endPoint('/definition')
      request = Net::HTTP::Post.new(uri)
      ret = nil

      specFile.open do |io|
        request.body_stream = io
        request.content_length = specFile.size
        set_def_headers(request)
        request.content_type = 'text/yaml'
        ret = workit(request)
      end
      ret
    end

    ## Write a value to an alias on a device
    def write(sn, values)
      post("/write/#{sn}", values)
    end

    ## Converts an exoline style spec file into a Murano style one
    # @param fin IO: IO Stream to read from
    # @return String: Converted yaml data
    def convertit(fin)
      specOut = {'resources'=>[]}
      spec = YAML.load(fin)
      if spec.has_key?('dataports') and spec['dataports'].kind_of?(Array) then
        dps = spec['dataports'].map do |dp|
          dp.delete_if{|k,v| k != 'alias' and k != 'format' and k != 'initial'}
          dp['format'] = 'string' if (dp['format']||'')[0..5] == 'string'
          dp
        end
        specOut['resources'] = dps
      else
        raise "No dataports section found, or not an array"
      end
      specOut
    end

    ## Converts an exoline style spec file into a Murano style one
    # @param specFile String: Path to file or '-' for stdin 
    # @return String: Converted yaml data
    def convert(specFile)
      if specFile == '-' then
        convertit($stdin).to_yaml
      else
        specFile = Pathname.new(specFile) unless specFile.kind_of? Pathname
        out = ''
        specFile.open() do |fin|
          out = convertit(fin).to_yaml
        end
        out
      end
    end
  end

  ## Manage the resources on a Product
  #
  # There isn't an okami-shim for most of this, it maps right over to 1P-RPC.
  class ProductResources < ProductBase
    def initialize
      super
      @uriparts << :proxy
      @uriparts << 'onep:v1'
      @uriparts << :rpc
      @uriparts << :process
      @model_rid = nil
    end

    def model_rid
      return @model_rid unless @model_rid.nil?
      prd = Product.new
      data = prd.info
      if data.kind_of?(Hash) and data.has_key?(:modelrid) then
        @model_rid = data[:modelrid]
      else
        raise "Bad info; #{data}"
      end
      @model_rid
    end

    ## Do a 1P RPC call
    #
    # While this will take an array of calls, don't. Only pass one.
    def do_rpc(calls)
      calls = [calls] unless calls.kind_of?(Array)
      r = post('', {
        :auth=>{:client_id=>model_rid},
        :calls=>calls
      })
      return r if not r.kind_of?(Array) or r.count < 1
      r = r[0]
      return r if not r.kind_of?(Hash) or r[:status] != 'ok'
      r[:result]
    end

    def info
      do_rpc({:id=>1,
              :procedure=>:info,
              :arguments=>[model_rid, {}]
      })
    end

    def list
      do_rpc({:id=>1,
              :procedure=>:listing,
              :arguments=>[model_rid, [:dataport], {:owned=>true}]
      })
    end

    def remove(rid)
      do_rpc({:id=>1,
              :procedure=>:drop,
              :arguments=>[rid]
      })
    end

    def remove_alias(aid)
      inf = info
      raise "Bad info" unless inf[:aliases].kind_of?(Hash)
      aliases = inf[:aliases].select{|k,v| v.include? aid}

      raise "Unknown alias: #{aid}" if aliases.count == 0

      aliases.each do |rid, aids|
        remove(rid)
      end

      {}
    end

    def create(alias_id, format=:string)
      # create then map.
      rid = do_rpc({:id=>1,
                  :procedure=>:create,
                  :arguments=>[:dataport,
                               {:format=>format,
                                :name=>alias_id,
                                :retention=>{:count=>1,:duration=>:infinity}
                               }
                              ]
      })
      return rid unless not rid.kind_of?(String) or rid.match(/\p{XDigit}{40}/)

      do_rpc({:id=>1,
              :procedure=>:map,
              :arguments=>[:alias, rid, alias_id]
      })
    end

    # XXX should this support the status/sync{up,down} system?
  end

  ##
  # Manage the uploadable content for products.
  class ProductContent < ProductBase
    def initialize
      super
      @uriparts << :proxy
      @uriparts << :provision
      @uriparts << :manage
      @uriparts << :content
      @uriparts << @pid
    end

    ## List all things in content area
    def list
      ret = get('/')
      return [] if ret.kind_of?(Hash)
      ret.lines.map{|i|i.chomp}
    end

    ## List all contents allowed for sn
    def list_for(sn)
      ret = get("/?sn=#{sn}")
      return [] if ret.kind_of?(Hash)
      ret.lines.map{|i|i.chomp}
    end

    ## Create a new content item
    def create(id, meta='', protect=false)
      http_reset
      data = {:id=>id, :meta=>meta}
      data[:protected] = true if protect
      postf('/', data)
    end

    ## Remove Content item
    def remove(id)
      postf('/', {:id=>id, :delete=>true})
    end

    ## Get info for content item
    def info(id)
      get("/#{id}") do |request, http|
        http.request(request) do |resp|
          case resp
          when Net::HTTPSuccess
            return CSV.parse(resp.body)
          else
            return nil
          end
        end
      end
    end

    ## Download data for content item
    def download(id, &block)
      get("/#{id}?download=true") do |request, http|
        http.request(request) do |resp|
          case resp
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
            raise resp
          end
        end
        nil
      end
    end

    ## Upload data for content item
    # TODO: add support for passing in IOStream
    def upload(id, path)
      path = Pathname.new(path) unless path.kind_of? Pathname

      mime = MIME::Types.type_for(path.to_s)[0] || MIME::Types["application/octet-stream"][0]
      uri = endPoint("/#{id}")
      request = Net::HTTP::Post.new(uri)
      ret = nil

      path.open do |io|
        request.body_stream = io
        set_def_headers(request)
        request.content_length = path.size
        request.content_type = mime.simplified
        ret = workit(request)
      end
      ret
    end

    ## Delete data for content item
    # Note that the content item is still present and listed.
    def remove_content(id)
      delete("/#{id}")
    end

  end

  ##
  # This is not applicable to Murano.  Remove?
  class ProductModel < ProductBase
    def initialize
      super
      @uriparts << :proxy
      @uriparts << :provision
      @uriparts << :manage
      @uriparts << :model
    end

    # In Murano, there should only ever be one.
    # AND it should be @pid
    def list
      get('/')
    end

    def info(modelID=@pid)
      get("/#{modelID}")
    end

    def list_sn(modelID=@pid)
      get("/#{modelID}/")
    end
  end

  ## TODO: Determine which of these are expected to be used.
  class ProductSerialNumber < ProductBase
    def initialize
      super
      @uriparts << :proxy
      @uriparts << :provision
      @uriparts << :manage
      @uriparts << :model
      @uriparts << @pid
    end

    def list(offset=0, limit=1000)
      ret = get("/?offset=#{offset}&limit=#{limit}&status=true")
      return [] if ret.kind_of?(Hash)
      CSV.parse(ret)
    end

    def logs(sn)
      get("/#{sn}?show=log") # results are empty
    end

    def regen(sn)
      postf("/#{sn}", {:enable=>true})
    end

    def disable(sn)
      postf("/#{sn}", {:disable=>true})
    end

    def activate(sn)
      uri = URI("https://#{@pid}.m2.exosite.com/provision/activate")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.start
      request = Net::HTTP::Post.new(uri)
      request.form_data = {
        :vendor => @pid,
        :model => @pid,
        :sn => sn
      }
      request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
      request['Authorization'] = nil
      request.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
      curldebug(request)
      response = http.request(request)
      case response
      when Net::HTTPSuccess
        return response.body
      else
        showHttpError(request, response)
        raise response
      end
    end

    def add_sn(sn, extra='')
      # this does add, but what does that mean?
      # Still need to call …/device/<sn> to enable.
      # How long is the activation window?
      postf('/', {:sn=>sn,:extra=>extra})
    end

    def remove_sn(sn)
      postf('/', {:sn=>sn, :delete=>true})
    end

    def ranges
      get('/?show=ranges')
    end

    def add_range()
      post('/', {:ranges=>[ ]})
    end

  end

end
#  vim: set ai et sw=2 ts=2 :
