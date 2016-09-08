
module MrMurano
  class Keystore < ServiceConfig
    def initialize
      super
      @serviceName = 'keystore'
    end

    def keyinfo
      ret = get("/#{scid}/call/info")
    end

    def listkeys
      ret = get("/#{scid}/call/list")
      ret[:keys]
    end

    def getkey(key)
      ret = post("/#{scid}/call/get", {:key=>key})
      ret[:value]
    end

    def setkey(key, value)
      post("/#{scid}/call/set", { :key=>key, :value=>value })
    end

    def delkey(key)
      post("/#{scid}/call/delete", { :key=>key})
    end

    def command(key, cmd, args)
      post("/#{scid}/call/command", {:key=>key, :command=>cmd, :args=>args})
    end

  end
end

command 'keystore info' do |c|
  c.syntax = %{mr keystore info}
  c.description = %{Show info about the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    pp sol.keyinfo
  end
end

command 'keystore list' do |c|
  c.syntax = %{mr keystore list}
  c.description = %{List all of the keys in the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.listkeys.each do |key|
      puts key
    end
  end
end
alias_command :keystore, 'keystore list'

command 'keystore get' do |c|
  c.syntax = %{mr keystore get <key>}
  c.description = %{Get the value of a key in the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    ret = sol.getkey(args[0])
    puts ret
  end
end

command 'keystore set' do |c|
  c.syntax = %{mr keystore set <key> <value...>}
  c.description = %{Set teh value of a key in the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.setkey(args[0], args[1..-1].join(' '))
  end
end

command 'keystore delete' do |c|
  c.syntax = %{mr keystore delete <key>}
  c.description = %{Delete a key from the Keystore}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    sol.delkey(args[0])
  end
end
alias_command 'keystore rm', 'keystore delete'

command 'keystore command' do |c|
  c.syntax = %{mr keystore command <key> <command> <args...>}
  c.description = %{Call some Redis commands in the Keystore.

Only a subset of all Redis commands is supported.
See http://docs.exosite.com/murano/services/keystore/#command for current list.
  }
  c.example %{mr keystore command mykey lpush myvalue}, %{Push a value onto list}
  c.example %{mr keystore command mykey lpush A B C}, %{Push three values onto list}
  c.example %{mr keystore command mykey lrem 0 B}, %{Remove all B values from list}
  c.action do |args,options|
    sol = MrMurano::Keystore.new
    pp sol.command(args[0], args[1], args[2..-1])
  end
end
alias_command 'keystore cmd', 'keystore command'

#  vim: set ai et sw=2 ts=2 :
