require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  class Keystore < ServiceConfig
    def initialize
      super
      @serviceName = 'keystore'
    end

    def keyinfo
      call(:info)
    end

    def listkeys
      ret = call(:list)
      ret[:keys]
    end

    def getkey(key)
      ret = call(:get, :post, {:key=>key})
      ret[:value]
    end

    def setkey(key, value)
      call(:set, :post, { :key=>key, :value=>value })
    end

    def delkey(key)
      call(:delete, :post, {:key=>key})
    end

    def command(key, cmd, args)
      call(:command, :post, {:key=>key, :command=>cmd, :args=>args})
    end

    def clearall()
      call(:clear, :post, {})
    end

  end
end

command :keystore do |c|
  c.syntax = %{murano keystore}
  c.summary = %{About Keystore}
  c.description = %{The Keystore sub-commands let you interact directly with the Keystore instance
in a solution.  This allows for easier debugging, being able to quickly get and
set data.  As well as calling any of the other supported REDIS commands.}
  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'keystore clearAll' do |c|
  c.syntax = %{murano keystore clearAll}
  c.description = %{Delete all keys in the keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.clearall
  end
end

command 'keystore info' do |c|
  c.syntax = %{murano keystore info}
  c.description = %{Show info about the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.outf sol.keyinfo
  end
end

command 'keystore list' do |c|
  c.syntax = %{murano keystore list}
  c.description = %{List all of the keys in the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.outf sol.listkeys
  end
end

command 'keystore get' do |c|
  c.syntax = %{murano keystore get <key>}
  c.description = %{Get the value of a key in the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    ret = sol.getkey(args[0])
    sol.outf ret
  end
end

command 'keystore set' do |c|
  c.syntax = %{murano keystore set <key> <value...>}
  c.description = %{Set the value of a key in the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.setkey(args[0], args[1..-1].join(' '))
  end
end

command 'keystore delete' do |c|
  c.syntax = %{murano keystore delete <key>}
  c.description = %{Delete a key from the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.delkey(args[0])
  end
end
alias_command 'keystore rm', 'keystore delete'
alias_command 'keystore del', 'keystore delete'

command 'keystore command' do |c|
  c.syntax = %{murano keystore command <command> <key> <args...>}
  c.summary = %{Call some Redis commands in the Keystore}
  c.description = %{Call some Redis commands in the Keystore.

Only a subset of all Redis commands is supported.
See http://docs.exosite.com/murano/services/keystore/#command for current list.
  }
  c.example %{murano keystore command lpush mykey myvalue}, %{Push a value onto list}
  c.example %{murano keystore command lpush mykey A B C}, %{Push three values onto list}
  c.example %{murano keystore command lrem mykey 0 B}, %{Remove all B values from list}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    if args.count < 2 then
      sol.error "Not enough params"
    else
      ret = sol.command(args[1], args[0], args[2..-1])
      if ret.has_key?(:value) then
        sol.outf ret[:value]
      else
        sol.error "#{ret[:code]}: #{ret.message}"
        sol.outf ret[:error] if ($cfg['tool.debug'] and ret.has_key?(:error))
      end
    end
  end
end
alias_command 'keystore cmd', 'keystore command'

# A bunch of common REDIS commands that are suported in Murano
alias_command 'keystore lpush', 'keystore command', 'lpush'
alias_command 'keystore lindex', 'keystore command', 'lindex'
alias_command 'keystore llen', 'keystore command', 'llen'
alias_command 'keystore linsert', 'keystore command', 'linsert'
alias_command 'keystore lrange', 'keystore command', 'lrange'
alias_command 'keystore lrem', 'keystore command', 'lrem'
alias_command 'keystore lset', 'keystore command', 'lset'
alias_command 'keystore ltrim', 'keystore command', 'ltrim'
alias_command 'keystore rpop', 'keystore command', 'rpop'
alias_command 'keystore rpush', 'keystore command', 'rpush'
alias_command 'keystore sadd', 'keystore command', 'sadd'
alias_command 'keystore srem', 'keystore command', 'srem'
alias_command 'keystore scard', 'keystore command', 'scard'
alias_command 'keystore smembers', 'keystore command', 'smembers'
alias_command 'keystore spop', 'keystore command', 'spop'

#  vim: set ai et sw=2 ts=2 :
