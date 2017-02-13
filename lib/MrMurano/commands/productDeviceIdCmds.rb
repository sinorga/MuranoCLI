require 'MrMurano/Gateway'

command 'product device list' do |c|
  c.syntax = %{murano product device list [options]}
  c.summary = %{List serial numbers for a product}
  c.description = %{List serial numbers for a product

  The API for pagination of devices seems broken.
  }

  c.option '--limit NUMBER', Integer, %{How many devices to return}
  c.option '--before TIMESTAMP', Integer, %{Show devices before timestamp}
  c.option '-l', '--long', %{show everything}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args,options|
    #options.default :limit=>1000

    prd = MrMurano::Gateway::Device.new
    io=nil
    io = File.open(options.output, 'w') if options.output
    data = prd.list(options.limit, options.before)
    prd.outf(data, io) do |dd,ios|
      dt={}
      if options.long then
        dt[:headers] = [:Identifier,
                        :AuthType,
                        :Locked,
                        :Reprovision, 'Dev Mode', 'Last IP',
                        'Last Seen',
                        :Status, :Online]
        dt[:rows] = data[:devices].map{|row| [row[:identity],
                                    (row[:auth] or {})[:type],
                                    row[:locked],
                                    row[:reprovision],
                                    row[:devmode],
                                    row[:lastip],
                                    row[:lastseen],
                                    row[:status],
                                    row[:online]]}
      else
        dt[:headers] = [:Identifier, :Status, :Online]
        dt[:rows] = data[:devices].map{|row| [row[:identity], row[:status], row[:online]]}
      end
      prd.tabularize(dt, ios)
    end
    io.close unless io.nil?
  end
end

command 'product device enable' do |c|
  c.syntax = %{murano product device enable [<identifier>|--file <identifiers>]}
  c.summary = %{Enable an Identifier; Creates device in Murano}
  c.description = %{Enables identifiers, creating the digial shadow in Murano.
  }
  c.option '-f', '--file FILE', %{A file of serial numbers, one per line}

  c.action do |args,options|
    prd = MrMurano::Gateway::Device.new
    if options.file then
      prd.enable_batch(options.file)
    elsif args.count > 0 then
      prd.enable(args[0])
    else
      prd.error "Missing an identifier to enable"
    end
  end
end

command 'product device activate' do |c|
  c.syntax = %{murano product device activate <identifier>}
  c.summary = %{Activate a serial number, retriving its CIK}
  c.description = %{Activates an Identifier.

Generally you should not use this.  Instead the device should make the activation
call itself and save the CIK token.  Its just that sometimes when building a
proof-of-concept it is just easier to hardcode the CIK.

Note that you can only activate a device once.  After that you cannot retrive the
CIK again.
}

  c.action do |args,options|
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      return
    end

    prd.outf prd.activate(args.first)

  end
end

alias_command 'sn list', 'product device list'
alias_command 'sn enable', 'product device enable'
alias_command 'sn activate', 'product device activate'
command 'device delete' do |c|
  c.syntax = %{murano device delete <identifier>}
  c.summary = %{Delete a device}

  c.action do |args,options|
    snid = args.shift
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      exit 1
    end

    ret = prd.remove(snid)
    prd.outf ret unless ret.empty?
  end
end

#  vim: set ai et sw=2 ts=2 :
