require 'MrMurano/Product'

module MrMurano
  class Product1PDevice < ProductBase
    include ProductOnePlatformRpcShim

    def initialize
      super
      @uriparts << :proxy
      @uriparts << 'onep:v1'
      @uriparts << :rpc
      @uriparts << :process
      @model_rid = nil
      @sn_rid = nil
    end

    def sn_rid(sn)
      return @sn_rid unless @sn_rid.nil?
      prd = Product.new()
      found = []

      offset = 0
      loop do
        listing = prd.list(offset)
        break if listing.empty?
        found = listing.select{|item| item[:sn] == sn}
        break unless found.empty?

        offset += 50
      end

      @sn_rid = found.first[:rid]
      @sn_rid
    end

    def info(sn)
      do_rpc({:id=>1,
              :procedure=>:info,
              :arguments=>[sn_rid(sn), {}]
      }, sn_rid(sn))
    end

    def list(sn)
      data = info(sn)
      dt = {}
      data[:aliases].each{|k,v| v.each{|a| dt[a] = k.to_s}}
      dt
    end

    def listing(sn)
      do_rpc({:id=>1,
              :procedure=>:listing,
              :arguments=>[sn_rid(sn), [:dataport], {}]
      }, sn_rid(sn))
    end

    def read(sn, aliases)
      aliases = [aliases] unless aliases.kind_of? Array
      idx=0
      calls = aliases.map do |a|
        idx+=1
        {:id=>idx,
         :procedure=>:read,
         :arguments=>[ {:alias=>a}, {} ]
        }
      end
      do_mrpc(calls, sn_rid(sn)).map{|i| i[:result].first[1]}
    end

  end

end

#  vim: set ai et sw=2 ts=2 :
