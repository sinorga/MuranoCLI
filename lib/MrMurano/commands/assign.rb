require 'MrMurano/Account'
require 'MrMurano/Solution-ServiceConfig'
require 'terminal-table'

command 'link list' do |c|
  c.syntax = 'murano link list [options]'
  c.description = 'List the solutions that are linked'
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all columns'

  c.action do |args, options|
    # List solutions(type=product)
    # List service configs.
    # Display where serviceconfig.service == products.apiId

    acc = MrMurano::Account.new
    products = acc.products
    pids = products.map{|p| p[:apiId]}

    sercfg = MrMurano::ServiceConfig.new
    scfgs = sercfg.list

    scfgs.select!{|s| pids.include? s[:service]}

    io = nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    if options.idonly then
      headers = [:service]
      scfgs = scfgs.map{|row| [row[:service]]}
    elsif not options.all then
      headers = [:name, :script_key, :service]
      scfgs = scfgs.map{|r| headers.map{|h| r[h]}}
    else
      headers = (scfgs.first or {}).keys
      scfgs = scfgs.map{|r| headers.map{|h| r[h]}}
    end

    sercfg.outf(scfgs, io) do |dd, ios|
      if options.idonly then
        ios.puts dd.join(' ')
      else
        acc.tabularize({
          :headers=>headers.map{|h| h.to_s},
          :rows=>dd
        }, ios)
      end
    end
    io.close unless io.nil?

  end
end
alias_command 'assign list', 'link list'

command 'link set' do |c|
  c.syntax = 'murano link set [product]'
  c.description = 'Link a solution to a eventhandler'

  c.action do |args, options|
    prname = args.shift
    if prname.nil? then
      prid = $cfg['product.id']
    else
      acc = MrMurano::Account.new
      products = acc.products # For now just products. Future, solutions with Interface service
      products.select!{|p| p[:name] == prname or p[:apiId]}
      prid = products.map{|p| p[:apiId]}.first
    end

    if prid.nil? or prid.empty? then
      say_error "No product id found!"
      exit 2
    end

    say "Linking #{prid} to solution" if $cfg['tool.verbose']

    sercfg = MrMurano::ServiceConfig.new
    ret = sercfg.create(prid)
    unless ret.nil? then
      say "Linked #{ret[:script_key]}"
    end
  end
end
alias_command 'assign set', 'link set'

command 'link unset' do |c|
  c.syntax = 'murano link unset [product]'
  c.description = 'Unlink a solution'

  c.action do |args, options|
    prname = args.shift
    if prname.nil? then
      prid = $cfg['product.id']
    else
      acc = MrMurano::Account.new
      products = acc.products # For now just products. Future, solutions with Interface service
      products.select!{|p| p[:name] == prname or p[:apiId]}
      prid = products.map{|p| p[:apiId]}.first
    end

    if prid.nil? or prid.empty? then
      say_error "No product id found!"
      exit 2
    end

    sercfg = MrMurano::ServiceConfig.new
    sercfg.verbose "Unlinking #{prid} to solution"

    scfgs = sercfg.list.select{|s| s[:service] == prid}
    scfgs.each do |s|
      sercfg.debug "Deleting #{s[:service]} : #{s[:script_key]} : #{s[:id]}"
      ret = sercfg.remove(s[:id])
      say "Unlinked #{s[:script_key]}" unless ret.nil?
    end
  end
end
alias_command 'assign unset', 'link unset'



#  vim: set ai et sw=2 ts=2 :
