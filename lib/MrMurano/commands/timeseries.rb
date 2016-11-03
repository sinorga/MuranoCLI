require 'csv'

module MrMurano
  class Timeseries < ServiceConfig
    def initialize
      super
      @serviceName = 'timeseries'
    end

    def query(query)
      post("/#{scid}/call/query", {:q=>query})
    end

    def write(writestr)
      post("/#{scid}/call/write", { :query=>writestr })
    end

    def command(cmd)
      post("/#{scid}/call/command", { :q=>cmd})
    end

  end
end

command 'timeseries query' do |c|
  c.syntax = %{mr timeseries query <query string>}
  c.description = %{Query the timeseries database}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}
  c.option '--[no-]json', %{Display results as raw json}
  c.option '--[no-]csv', %{Display results as CSV}

  c.action do |args,options|
    options.defalts :json=>false, :csv=>false
    sol = MrMurano::Timeseries.new
    ret = sol.query args.join(' ')

    $cfg['tool.outformat'] = 'json' if options.json
    $cfg['tool.outformat'] = 'best csv' if options.csv

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    sol.outf(ret, io) do |dd, ios|
      (ret[:results] or []).each do |res|
        (res[:series] or []).each do |ser|
          sol.tabularize({
            :title=>ser[:name],
            :headings=>ser[:columns],
            :rows=>ser[:values]
          }, ios)
        end
      end
    end
    io.close unless io.nil?

  end
end
alias_command :tsq, 'timeseries query'

command 'timeseries write' do |c|
  c.syntax = %{mr timeseries <write string>}
  c.description = %{Write data into the timeseries database}
  c.option '--[no-]json', %{Display results as raw json}
  c.action do |args,options|
    options.defalts :json=>false
    $cfg['tool.outformat'] = 'json' if options.json
    sol = MrMurano::Timeseries.new
    ret = sol.write args.join(' ')
    sol.outf ret
  end
end
alias_command :tsw, 'timeseries write'

command 'timeseries command' do |c|
  c.syntax = %{mr timeseries command <db command>}
  c.description = %{Execute a non-query command in the database}
  c.option '--[no-]json', %{Display results as raw json}
  c.action do |args,options|
    options.defalts :json=>false
    $cfg['tool.outformat'] = 'json' if options.json
    sol = MrMurano::Timeseries.new
    ret = sol.command args.join(' ')
    sol.outf ret
  end
end


#  vim: set ai et sw=2 ts=2 :
