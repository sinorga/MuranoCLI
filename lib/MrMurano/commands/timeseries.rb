require 'csv'
require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  class Timeseries < ServiceConfig
    def initialize
      super
      @serviceName = 'timeseries'
    end

    def query(query)
      call(:query, :post, {:q=>query})
    end

    def write(writestr)
      call(:write, :post, { :query=>writestr })
    end

    def command(cmd)
      call(:command, :post, { :q=>cmd})
    end

  end
end

command :timeseries do |c|
  c.syntax = %{mr timeseries}
  c.summary = %{About Timeseries}
  c.description = %{The timeseries sub-commands let you interact directly with the Timeseries
instance in a solution.  This allows for easier debugging, being able to
quickly try out different queries or write test data.}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
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
            :headers=>ser[:columns],
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
