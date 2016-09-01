
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

#  vim: set ai et sw=2 ts=2 :
