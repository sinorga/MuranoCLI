require 'MrMurano/Product'
require 'MrMurano/SyncUpDown'

module MrMurano

  ## Manage the resources on a Product
  #
  # There isn't an okami-shim for most of this, it maps right over to 1P-RPC.
  # Or better stated, that's all okami-shim is.
  class ProductResources < ProductBase
    include SyncUpDown

    def initialize
      super
      @uriparts << :proxy
      @uriparts << 'onep:v1'
      @uriparts << :rpc
      @uriparts << :process
      @model_rid = nil

      @itemkey = :rid # this is the key that is the identifier used by murano
      @location = location
    end

    ## Get the location of the product spec file
    def location
      # If location.specs is defined, then all spec files are assume to be relative
      # to that and location.base, otherwise they're relative to only location.base
      #
      # If there is a p-<product.id>.spec key, then that is the file name.
      # Otherwise use product.spec

      name = $cfg['product.spec']
      prid = $cfg['product.id']
      name = $cfg["p-#{prid}.spec"] unless prid.nil? or $cfg["p-#{prid}.spec"].nil?

      unless $cfg['location.specs'].nil? then
        name = File.join($cfg['location.specs'], name)
      end
      name
    end

    ## The model RID for this product.
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
    private :do_rpc

    ## Get 1P info about the prodcut
    def info
      do_rpc({:id=>1,
              :procedure=>:info,
              :arguments=>[model_rid, {}]
      })
    end

    ## Return a list of the product resources as items
    def list()
      data = info()
      ret = []
      data[:aliases].each do |rid, aliases|
        aliases.each do |al|
          ret << {
            :alias => al,
            :name => al,
            :rid => rid
          }
        end
      end

      ret
    end

    ## Remove a resource by RID
    def remove(rid)
      do_rpc({:id=>1,
              :procedure=>:drop,
              :arguments=>[rid]
      })
    end

    ## Remove a resource by alias
    # XXX might not need this.
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

    ## Create a new resource in the prodcut
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

    ## Upload a resource.
    # this is for SyncUpDown
    # @param modify Bool: True if item exists already and this is changing it
    def upload(src, item, modify)
      if modify then
        # this is usually a format change, which can only be set on create.
        # So delete then create.
        remove(item[:rid])
      end
      create(item[:name], item[:format])
    end

    ## Use alias for doing sync compares
    # (The RID will change if destroyed and recreated.)
    def synckey(item)
      item[:alias]
    end

    ## Get a local list of items from the single file
    def localitems(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      if not from.exist? then
        say_warning "Skipping missing #{from.to_s}"
        return []
      end
      unless from.file? then
        say_warning "Cannot read from #{from.to_s}"
        return []
      end

      here = []
      from.open {|io| here = YAML.load(io) }
      return [] if here == false

      if here.kind_of?(Hash) and here.has_key?('resources') then
        here['resources'].map{|i| Hash.transform_keys_to_symbols(i)}
      else
        []
      end
    end

    def download(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist? then
        local.open('rb') {|io| here = YAML.load(io)}
        here = [] if here == false
      end
      here.delete_if do |i|
        Hash.transform_keys_to_symbols(i)[@itemkey] == item[@itemkey]
      end
      here << item.reject{|k,v| k==:synckey}
      local.open('wb') do |io|
        io.write here.map{|i| Hash.transform_keys_to_strings(i)}.to_yaml
      end
    end

    def removelocal(dest, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist? then
        local.open('rb') {|io| here = YAML.load(io)}
        here = [] if here == false
      end
      key = @itemkey.to_sym
      here.delete_if do |it|
        Hash.transform_keys_to_symbols(it)[key] == item[key]
      end
      local.open('wb') do|io|
        io.write here.map{|i| Hash.transform_keys_to_strings(i)}.to_yaml
      end
    end

    ##
    # True if itemA and itemB are different
    def docmp(itemA, itemB)
      itemA[:alias] == itemB[:alias] and itemA[:format] == itemB[:format]
    end

  end
  SyncRoot.add('specs', ProductResources, 'P', %{Product Specification})

end
#  vim: set ai et sw=2 ts=2 :
