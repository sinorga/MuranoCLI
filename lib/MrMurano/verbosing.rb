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
  end
end
#  vim: set ai et sw=2 ts=2 :
