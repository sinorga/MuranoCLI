require 'MrMurano/Product'
require 'terminal-table'

command 'sn list' do |c|
  c.syntax = %{mr sn list [options]}
  c.summary = %{List serial numbers for a product}

  c.option '--offset NUMBER', Integer, %{Offset to start listing at}
  c.option '--limit NUMBER', Integer, %{How many devices to return}

  c.action do |args,options|
    options.default :offset=>0, :limit=>50

    prd = MrMurano::Product.new
    data = prd.list(options.offset, options.limit)
    busy = data.map{|row| [row[:sn], row[:status], row[:rid]]}
    table = Terminal::Table.new :rows => busy, :headings => ['SN', 'Status', 'RID']
    say table
  end
end
alias_command :sn, 'sn list'

command 'sn enable' do |c|
  c.syntax = %{mr sn enable [<sn>|--file <sns>]}
  c.summary = %{Enable a serial number; Creates device in Murano}
  c.description = %{Enables serial numbers, creating the digial shadow in Murano.

NOTE: This opens the 24 hour activation window.  If the device does not make
the activation call within this time, it will need to be enabled again.
  }
  c.option '-f', '--file FILE', %{A file of serial numbers, one per line}

  c.action do |args,options|
    prd = MrMurano::Product.new
    if options.file then
      File.open(options.file) do |io|
        io.each_line do |line|
          line.strip!
          prd.enable(line) unless line.empty?
        end
      end
    elsif args.count > 0 then
      prd.enable(args[0])
    else
      say_error "Missing a serial number to enable"
    end
  end
end

command 'sn activate' do |c|
  c.syntax = %{mr sn activate <sn>}
  c.summary = %{Activate a serial number, retriving its CIK}
  c.description = %{Activates a serial number.

Generally you should not use this.  Instead the device should make the activation
call itself and save the CIK token.  Its just that sometimes when building a
proof-of-concept it is just easier to hardcode the CIK.

Note that you can only activate a device once.  After that you cannot retrive the
CIK again.
}

  c.action do |args,options|
    if args.count < 1 then
      say_error "Serial number missing"
      return
    end
    sn = args.first

    prd = MrMurano::ProductSerialNumber.new
    prd.outf prd.activate(sn)

  end
end
#  vim: set ai et sw=2 ts=2 :
