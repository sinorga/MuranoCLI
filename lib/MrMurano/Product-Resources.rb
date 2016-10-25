require 'MrMurano/Product'
require 'MrMurano/SyncUpDown'

module MrMurano

  ## Manage the resources on a Product
  #
  # There isn't an okami-shim for most of this, it maps right over to 1P-RPC.
  # Or better stated, that's all okami-shim is.
  class ProductResources < ProductBase
    def initialize
      super
      @uriparts << :proxy
      @uriparts << 'onep:v1'
      @uriparts << :rpc
      @uriparts << :process
      @model_rid = nil
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

    # XXX should this support the status/sync{up,down} system? Yes
    include SyncUpDown

  end

end
#  vim: set ai et sw=2 ts=2 :
