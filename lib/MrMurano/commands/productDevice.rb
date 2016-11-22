require 'MrMurano/Product-1P-Device'

command 'product device' do |c|
end

command 'product device read' do |c|
  c.syntax = %{mr product device read <identifier> (<resources>)}
  c.summary = %{Read recources on a device}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args,options|
    snid = args.shift
    prd = MrMurano::Product1PDevice.new

    if args.count == 0 then
      # fetch list and read all
      args = prd.list(snid).keys
    end

    io=nil
    io = File.open(options.output, 'w') if options.output
    data = prd.read(snid, args)
    prd.outf(data, io)
    io.close unless io.nil?

  end
end

command 'product device twee' do |c|
  c.syntax = %{mr product device twee <identifier>}
  c.summary = %{Show info about a device}


  c.action do |args,options|
    snid = args.shift
    prd = MrMurano::Product1PDevice.new
    data = prd.twee(snid)

    # TODO build highline style template for output

    io=nil
    io = File.open(options.output, 'w') if options.output
    prd.outf(data, io) do |dd,ios|
      # Best output is pretty.
      say "#{snid} #{dd[:description][:name]} #{dd[:basic][:status]}"
      dd[:children].each do |child|
        name = child[:description][:name] or child[:alias]
        value = child[:value]
        if value.kind_of? String and value.length > 12 then
          value = value[0..12]
        end
        say " ├─#{name} #{child[:description][:format]} #{value or ''} (#{child[:basic][:modified]})"
      end
    end
    io.close unless io.nil?
  end
end

#  vim: set ai et sw=2 ts=2 :
