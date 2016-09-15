require 'uri'
require 'mime/types'
require 'csv'
require 'pp'

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
    def info
      get('/info')
    end

    def list(offset=0, limit=50)
      get("/device/?offset=#{offset}&limit=#{limit}")
    end

    def enable(sn)
      post("/device/#{sn.to_s}")
    end

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

    def write(sn, values)
      post("/write/#{sn}", values)
    end

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
              resp.read_body &block
            else
              resp.read_body do |chunk|
                $stdout.write chunk
              end
            end
          else
            say_error "got #{resp.to_s} from #{request} #{request.uri.to_s}"
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
      # TODO: Need to create a new @http for the different host. Fails otherwise
      uri = URI("https://#{@pid}.m2.exosite.com/provision/activate")
      request = Net::HTTP::Post.new(uri)
      request.form_data = {
        :vendor => @pid,
        :model => @pid,
        :sn => sn
      }
      request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
      request['authorization'] = nil
      request.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
      workit(request)
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
