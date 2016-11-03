require 'date'
require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  module ServiceConfigs
    class Tsdb < ServiceConfig
      def initialize
        super
        @serviceName = 'tsdb'
      end

      def write(data)
        call(:write, :post, data)
      end

      def query(query)
        call(:query, :post, data)
      end

      def listTags
        call(:listTags)
      end

      def listMetrics
        call(:listMetrics)
      end


      def str_to_timestamp(str)
        if str =~ /^\d+(u|ms|s)?$/ then
          str
        else
          dt = DateTime.parse(str)
          (dt.to_time.to_f * 1000000).to_i
        end
      end
    end
  end
end

command 'tsdb write' do |c|
  c.syntax = %{mr tsdb write [options] <metric=value>|@<tag=value> … }
  c.summary = %{write data}
  c.description = %{Write data

TIMESTAMP is microseconds since unix epoch, or can be suffixed with units.
Units are u (microseconds), ms (milliseconds), s (seconds)

Also, many date-time formats can be parsed and will be converted to microseconds
  }
  c.option '--when TIMESTAMP', %{When this data happened. (defaults to now)}
  # TODO: add option to take data from STDIN.

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new

    # we have hash of tags, hash of metrics, optional timestamp.
    metrics = {}
    tags = {}
    args.each do |item|
      key, value = item.split('=', 2)
      if key[0] == '@' then
        tags[key[1..-1]] = value.to_s  #tags are always strings.
      else
        value = value.to_i if value == value.to_i.to_s
        metrics[key] = value
      end
    end

    data = {:tags=>tags, :metrics=>metrics}
    if not options.when.nil? and options.when != 'now' then
      data[:ts] = sol.str_to_timestamp(options.when)
    end

    ret = sol.write(data)
    if ret != {} then
      sol.error ret
    end
  end
end

command 'tsdb query' do |c|
  c.syntax = %{mr tsdb query [options] }
  c.summary = %{query data}
  c.description =%{

  list metrics to return
  list tag=value to match


FUNCS is a comma seperated list of the aggregate functions.
FILL is null, none, any integer, previous

DURATION is an integer with time unit to indicate relative time before now.
Units are u (microseconds), ms (milliseconds), s (seconds), m (minutes),
h (hours), d (days), w (weeks)

TIMESTAMP is microseconds since unix epoch, or can be suffixed with units.
Units are u (microseconds), ms (milliseconds), s (seconds)

Also, many date-time formats can be parsed and will be converted to microseconds
  }
  c.option '--start_time TIMESTAMP', %{Start time range}
  c.option '--end_time TIMESTAMP', %{End time range; defaults to now}
  c.option '--relative_start DURATION', %{Start time relative from now}
  c.option '--relative_end DURATION', %{End time relative from now}
  c.option '--sampling_size DURATION', %{The size of time slots used for downsampling}
  c.option '--limit NUM', Integer, %{Limit number of data points returned}
  c.option '--epoch UNIT', ['u','ms','s'], %{Set size of returned timestamps}
  c.option '--mode MODE', ['merge','split'], %{Merge or split each returned metric}
  c.option '--fill FILL', %{Value to fill for time slots with no data points exist in merge mode}
  c.option '--order_by ORDER', ['desc','asc'], %{Return results in ascending or descending time order}
  c.option '--aggregate FUNCS', %{Aggregation functions to apply}

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new

    query = {}
    tags = {}
    metrics = []
    args.each do |arg|
      if arg =~ /=/ then
        # a tag.
        k,v = arg.split('=', 2)
        tags[k] = v
      else
        metrics << arg
      end
    end
    query[:tags] = tags unless tags.empty?
    query[:metrics] = metrics unless metrics.empty?

    unless options.start_time.nil? then
      query[:start_time] = sol.str_to_timestamp(options.start_time)
    end
    unless options.end_time.nil? then
      query[:end_time] = sol.str_to_timestamp(options.end_time)
    end

    query[:relative_start] = options.relative_start unless options.relative_start.nil?
    query[:relative_end] = options.relative_end unless options.relative_end.nil?
    query[:sampling_size] = options.sampling_size unless options.sampling_size.nil?

    query[:limit] = options.limit unless options.limit.nil?
    query[:epoch] = options.epoch unless options.epoch.nil?
    query[:mode] = options.mode unless options.mode.nil?
    query[:order_by] = options.order_by unless options.order_by.nil?

    query[:fill] = options.fill unless options.fill.nil?
    unless options.aggregate.nil? then
      query[:aggregate] = options.aggregate.split(',')
    end

    sol.outf query
  end
end

command 'tsdb list tags' do |c|
  c.syntax = %{mr tsdb list tags [options]}
  c.summary = %{List tags}

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listTags
    # TODO: handle looping if :next != nil
    sol.outf ret[:tags].keys
  end
end

command 'tsdb list metrics' do |c|
  c.syntax = %{mr tsdb list metrics [options]}
  c.summary = %{List metrics}

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listMetrics
    # TODO: handle looping if :next != nil
    sol.outf ret[:metrics]
  end
end

#  vim: set ai et sw=2 ts=2 :
