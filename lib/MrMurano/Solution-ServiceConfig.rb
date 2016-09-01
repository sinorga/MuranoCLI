require 'terminal-table'

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
      scid = scr[:id]
    end

    def assignTriggers(products)
      scid = scid_for_name('device')

      details = fetch(scid)
      products = [products] unless products.kind_of? Array
      details[:triggers] = {:pid=>products}

      put('/'+scid, details)

    end

    def showTriggers
      scid = scid_for_name('device')

      details = fetch(scid)

      return [] if details[:triggers].nil?
      details[:triggers][:pid]
    end

  end
end

command :assign do |c|
  c.syntax = 'mr assign [product]'
  c.description = 'Assign a product to a eventhandler'

  c.option '--list', %{List assigned products}
  c.option '--idonly', 'Only return the ids'

  c.action do |args, options|
    sol = MrMurano::ServiceConfig.new

    if options.list then
      trigs = sol.showTriggers()
      if options.idonly then
        say trigs.join(' ')
      else
        acc = MrMurano::Account.new
        products = acc.products
        products.select!{|p| trigs.include? p[:pid] }
        busy = products.map{|r| [r[:label], r[:type], r[:pid], r[:modelId]]}
        table = Terminal::Table.new :rows => busy, :headings => ['Label', 'Type', 'PID', 'ModelID']
        say table
      end

    else
      prname = args.shift
      if prname.nil? then
        prid = $cfg['product.id']
      else
        acc = MrMurano::Account.new
        products = acc.products
        products.select!{|p| p[:label] == prname or p[:pid] == prname }
        prid = products.map{|p| p[:pid]}
      end
      raise "No product ID!" if prid.nil?
      say "Assigning #{prid} to solution" if $cfg['tool.verbose']
      sol.assignTriggers(prid) unless $cfg['tool.dry']
    end


  end
end

#  vim: set ai et sw=2 ts=2 :
