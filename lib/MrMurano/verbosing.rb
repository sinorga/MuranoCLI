require 'highline'
require 'yaml'
require 'json'
require 'pp'

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


    ## Format and print the object
    def outf(obj, ios=nil, &block)
      fmt = $cfg['tool.outformat']
      ios = $stdout if ios.nil?
      case fmt
      when /yaml/i
        ios.puts obj.to_yaml
      when /pp/
        pp obj
      when /json/i
        ios.puts obj.to_json
      else # aka best.
        # sometime ‘best’ is only know by the caller, so block.
        if block_given? then
          yield obj
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
