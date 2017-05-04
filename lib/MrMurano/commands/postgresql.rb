require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  class Postgresql < ServiceConfig
    def initialize
      super
      @serviceName = 'postgresql'
    end

    def query(query)
      call(:query, :post, {:sql=>query})
    end

    def queries(query)
      call(:queries, :post, {:sql=>query})
    end
  end
end

command :postgresql do |c|
  c.syntax = %{murano postgresql <SQL Commands>}
  c.summary = %{Query the relational database}

  c.option '-f', '--file FILE', %{File of SQL commands}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args,options|
    pg = MrMurano::Postgresql.new
    if options.file then
      sqls = File.read(options.file)

      ret = pg.queries sqls
    else
      ret = pg.query args.join(' ')
    end

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    pg.outf(ret, io) do |dd, ios|
      pg.tabularize({
        :headers=>dd[:columns],
        :rows=>dd[:rows]
      }, ios)
    end
    io.close unless io.nil?

  end
end
#  vim: set ai et sw=2 ts=2 :
