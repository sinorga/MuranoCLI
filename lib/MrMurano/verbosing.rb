require 'highline'
require 'yaml'
require 'json'
require 'pp'
require 'csv'
require 'terminal-table'

module MrMurano
  module Verbose
    def verbose(msg)
      if $cfg['tool.verbose'] then
        say msg
      end
    end

    def debug(msg)
      if $cfg['tool.debug'] then
        say msg
      end
    end

    def warning(msg)
      $stderr.puts HighLine.color(msg, :yellow)
    end

    def error(msg)
      $stderr.puts HighLine.color(msg, :red)
    end

    def tabularize(data, ios=nil)
      fmt = $cfg['tool.outformat']
      ios = $stdout if ios.nil?
      cols = []
      rows = [[]]
      title = nil
      if data.kind_of?(Hash) then
        cols = data[:headers] if data.has_key?(:headers)
        rows = data[:rows] if data.has_key?(:rows)
        title = data[:title]
      elsif data.kind_of?(Array) then
        rows = data
      elsif data.respond_to?(:to_a) then
        rows = data.to_a
      elsif data.respond_to?(:each) then
        rows = []
        data.each{|i| rows << i}
      else
        error "Don't know how to tabularize data."
        return
      end
      if fmt =~ /csv/i then
        CSV(ios, :headers=>cols, :write_headers=>(not cols.empty?)) do |csv|
          rows.each{|v| csv << v}
        end
      else
        # table.
        ios.puts Terminal::Table.new :title=>title, :headings=>cols, :rows=>rows
      end
    end

    ## Format and print the object
    def outf(obj, ios=nil, &block)
      fmt = $cfg['tool.outformat']
      ios = $stdout if ios.nil?
      case fmt
      when /yaml/i
        ios.puts Hash.transform_keys_to_strings(obj).to_yaml
      when /pp/
        pp obj
      when /json/i
        ios.puts obj.to_json
      else # aka best.
        # sometime ‘best’ is only know by the caller, so block.
        if block_given? then
          yield obj, ios
        else
          if obj.kind_of?(Array) then
            obj.each {|i| ios.puts i.to_s}
          else
            ios.puts obj.to_s
          end
        end
      end
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
