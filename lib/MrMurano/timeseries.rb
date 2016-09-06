
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
      post("/#{scid}/call/write", { :q=>writestr })
    end

    def command(cmd)
      post("/#{scid}/call/command", { :q=>cmd})
    end

  end
end

command 'timeseries query' do |c|
  c.syntax = %{mr timeseries query <query string>}
  c.description = %{Query the timeseries database}
  c.option '--[no-]json', %{Display results as raw json}
  #c.option '--csv', %{Display results as csv}
  # Should get a CSV formatter to make sure cells are properly escapped.
  c.action do |args,options|
    options.defalts :json=>false
    sol = MrMurano::Timeseries.new
    ret = sol.query args.join(' ')
    if options.json then
      puts ret.to_json
    else
      (ret[:results] or []).each do |res|
        (res[:series] or []).each do |ser|
          cols = ser[:columns]
          table = Terminal::Table.new :title=>ser[:name], :headings=>cols, :rows=>ser[:values]
          puts table
        end
      end
      # If nothing displayed, Format wasn't what we expected, so do what?
    end
  end
end
alias_command :tsq, 'timeseries query'

command 'timeseries write' do |c|
  c.syntax = %{mr timeseries <write string>}
  c.description = %{Write data into the timeseries database}
  c.option '--[no-]json', %{Display results as raw json}
  c.action do |args,options|
    options.defalts :json=>false
    sol = MrMurano::Timeseries.new
    ret = sol.write args.join(' ')
    if options.json then
      puts ret.to_json
    else
      pp ret
    end
  end
end
alias_command :tsw, 'timeseries write'

command 'timeseries command' do |c|
  c.syntax = %{mr timeseries command <db command>}
  c.description = %{Execute a non-query command in the database}
  c.option '--[no-]json', %{Display results as raw json}
  c.action do |args,options|
    options.defalts :json=>false
    sol = MrMurano::Timeseries.new
    ret = sol.command args.join(' ')
    if options.json then
      puts ret.to_json
    else
      pp ret
    end
  end
end


#  vim: set ai et sw=2 ts=2 :
