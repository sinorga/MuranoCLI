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

    unless ret[:error].nil? then
      pg.error "Returned error: #{ret[:error]}"
      exit 1
    end

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    pg.outf(ret, io) do |dd, ios|
      dd = dd[:result]
      pg.tabularize({
        :headers=>dd[:columns],
        :rows=>dd[:rows]
      }, ios)
    end
    io.close unless io.nil?

  end
end

command 'postgresql migrate up' do |c|
  c.syntax = %{murano postgresql migrate up <level>}
  c.summary = %{}

  c.option '--dir DIR', %{Directory where migrations live}

  c.action do |args,options|
    options.default :dir => File.join($cfg['location.base'], 'sql-migrations')

    level = args.first

    pg = MrMurano::Postgresql.new

    # get current version of DB.
    ret = pg.queries %{
    CREATE TABLE IF NOT EXISTS __murano_cli_migrate__ (version integer);
    SELECT version FROM __murano_cli_migrate__;
    }.gsub(/^\s+/,'')
    unless ret[:error].nil? then
      pp ret
      exit 1
    end
    pg.debug "create/select: #{ret}"
    current_version = (((((ret[:result] or []).last or {})[:rows] or []).first or []).first or 0).to_i

    # Get migrations
    migrations = Dir[File.join(options.dir, '*-up.sql')].sort
    if migrations.empty? then
      pg.error "No migrations to run."
      exit 1
    end

    if level.nil? then
      level, _ = File.basename(migrations.last).split('-')
    end
    level = level.to_i
    pg.verbose "Will migrate from version #{current_version} to #{level}"
    if level <= current_version then
      say "Nothing to do."
      exit 0
    end

    # Select migrations between current and desired
    migrations.select! do |m|
      mvrs, _ = File.basename(m).split('-')
      mvrs = mvrs.to_i
      mvrs > current_version and mvrs <= level
    end

    # Run migrations.
    migrations.each do |m|
      mvrs, _ = File.basename(m).split('-')
      pg.verbose "Running migration: #{File.basename(m)}"
      unless $cfg['tool.dry'] then
        pg.query 'BEGIN;'
        ret = pg.queries File.read(m)
        unless ret[:error].nil? then
          pg.query 'ROLLBACK;'
          pg.error "Migrations failed at level #{mvrs}"
          pg.error "Because: #{ret[:error]}"
          exit 5
        else
          pg.queries %{INSERT INTO __murano_cli_migrate__ values (#{mvrs});
          DELETE FROM __murano_cli_migrate__ WHERE version <> #{mvrs};
          COMMIT;}.gsub(/^\s+/,'')
        end
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
