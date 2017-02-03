require 'MrMurano/Account'

command 'business list' do |c|
  c.syntax = %{mr business list [options]}
  c.description = %{List businesses}
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args, options|
    acc = MrMurano::Account.new
    data = acc.businesses

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    if options.idonly then
      headers = [:bizid]
      data = data.map{|row| [row[:bizid]]}
    elsif not options.all then
      headers = [:bizid, :role, :name]
      data = data.map{|r| [r[:bizid], r[:role], r[:name]]}
    else
      headers = data[0].keys
      data = data.map{|r| headers.map{|h| r[h]}}
    end

    acc.outf(data, io) do |dd, ios|
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

#  vim: set ai et sw=2 ts=2 :
