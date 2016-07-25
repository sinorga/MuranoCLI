
module MrMurano
  # …/serviceconfig
  class ServiceConfig < SolutionBase
    def initialize
      super
      @uriparts << 'serviceconfig'
    end

    def list
      get()['items']
    end
    def fetch(id)
      get('/' + id.to_s)
    end
  end

end

command :prodSet do |c|
  c.syntax = ''
  c.description = ' Needs a better name'

  c.action do |args, options|
    sol = MrMurano::ServiceConfig.new
    scs = sol.list
    scr = scs.select{|i| i['service'] == 'device' or i[:service] == 'device'}
    scid = scr['id'] or scr[:id]
    raise "No Device Service!" if scid.nil?

    prid = $cfg['product.id']
    raise "No product ID!" if prid.nil?

    details = sol.fetch(scid)
    Hash.transform_keys_to_symbols(details)
    # XXX Currently we overwrite this.  In the future we will need to append as
    # well as replace.
    details[:triggers] = {:pid=>[prid], :vendor=>[prid]}

    sol.put('/'+scid, details)

  end
end

#  vim: set ai et sw=2 ts=2 :
