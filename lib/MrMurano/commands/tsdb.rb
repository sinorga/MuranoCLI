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

    end
  end
end

command 'tsdb write' do |c|
  c.syntax = %{mr tsdb write [options] <metric=value> (<metric=value>…)}
  c.description = %{}
  c.option '--when TIMESTAMP', %{When this data happened. (defaults to now)}

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
    if options.when =~ /^\d+(u|ms|s)?$/ then
      # in acceptable format.
      data[:ts] = options.when
    elsif not options.when.nil? then
      dt = DateTime.parse(options.when)
      data[:ts] = (dt.to_time.to_f * 1000000).to_i
    end

    ret = sol.write(data)
    if ret != {} then
      sol.error ret
    end
  end
end

command 'tsdb list tags' do |c|
  c.syntax = %{mr tsdb list tags [options]}
  c.description = %{List tags}

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listTags
    # TODO: handle looping if :next != nil
    sol.outf ret[:tags].keys
  end
end

command 'tsdb list metrics' do |c|
  c.syntax = %{mr tsdb list metrics [options]}
  c.description = %{List metrics}

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listMetrics
    # TODO: handle looping if :next != nil
    sol.outf ret[:metrics]
  end
end

#  vim: set ai et sw=2 ts=2 :
