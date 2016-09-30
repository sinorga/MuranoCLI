require 'MrMurano/Product'

command 'product enable' do |c|
  c.syntax = %{mr product enable [<sn>|--file <sns>]}
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

#  vim: set ai et sw=2 ts=2 :
