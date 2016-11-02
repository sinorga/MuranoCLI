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


    ## Format and print the object
    def outf(obj)
      fmt = $cfg['tool.outformat']
      case fmt
      when /yaml/i
        $stdout.puts obj.to_yaml
      when /pp/
        pp obj
      when /json/i
        $stdout.puts obj.to_json
      else # aka plain.
        if obj.kind_of?(Array) then
          obj.each {|i| $stdout.puts i.to_s}
        else
          $stdout.puts obj.to_s
        end
      end
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
