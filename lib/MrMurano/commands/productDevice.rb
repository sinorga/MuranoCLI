require 'MrMurano/Product-1P-Device'

command 'product device' do |c|
  c.syntax = %{mr product device}
  c.summary = %{Interact with a device in a product}
  c.description = %{}

  c.action do |a,o|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
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
    options.default :width=>HighLine::SystemExtensions.terminal_size[0]
    snid = args.shift
    prd = MrMurano::Product1PDevice.new
    data = prd.twee(snid)

    io=nil
    io = File.open(options.output, 'w') if options.output
    prd.outf(data, io) do |dd,ios|
      data={}
      data[:title] = "#{snid} #{dd[:description][:name]} #{dd[:basic][:status]}"
      data[:headers] = [:Resource, :Format, :Modified, :Value]
      data[:rows] = dd[:children].map do |child|
        [ (child[:description][:name] or child[:alias]),
          child[:description][:format],
          child[:basic][:modified],
          (child[:value] or "").to_s[0..22] # TODO adjust based on terminal width
        ]
      end
      prd.tabularize(data, ios)
    end
    io.close unless io.nil?
  end
end

#  vim: set ai et sw=2 ts=2 :
