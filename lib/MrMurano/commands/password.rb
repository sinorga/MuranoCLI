
command :password do |c|
  c.syntax = %{murano password}
  c.summary = %{About password commands}
  c.description = %{Sub-commands for working with usernames and passwords}
  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

alias_command 'password current', :config, 'user.name'

class Outter
  include MrMurano::Verbose
end

command 'password list' do |c|
  c.syntax = %{murano password list}
  c.summary = %{List the usernames with saved passwords}
  c.description = %{List the usernames and hosts that have been saved}
  c.action do |args, options|
    psd = MrMurano::Passwords.new
    psd.load

    ret = psd.list
    outter = Outter.new
    outter.outf(ret) do |dd, ios|
      rows=[]
      dd.each_pair do |key, value|
        value.each{|v| rows << [key, v] }
      end
      outter.tabularize({
        :rows=>rows, :headers => [:Host, :Username]
      }, ios)
    end

  end

end

command 'password set' do |c|
  c.syntax = %{murano password set <username> [<host>]}
  c.summary = %{Set password for username}

  c.option '--password PASSWORD', String, %{The password to use}
  c.option '--from_env', %{Use password in MURANO_PASSWORD}

  c.action do |args, options|
    psd = MrMurano::Passwords.new
    psd.load

    username = args.shift
    host = args.shift
    host = $cfg['net.host'] if host.nil?

    if options.password then
      pws = options.password
    elsif options.from_env then
      pws = ENV['MURANO_PASSWORD']
    else
      pws = ask("Password:  ") { |q| q.echo = "*" }
    end

    psd.set(host, username, pws)
    psd.save

  end
end

command 'password delete' do |c|
  c.syntax = %{murano password delete <username> [<host>]}
  c.summary = %{Delete password for username}

  c.action do |args, options|
    psd = MrMurano::Passwords.new
    psd.load

    username = args.shift
    host = args.shift
    host = $cfg['net.host'] if host.nil?

    psd.remove(host, username)
    psd.save
  end
end

#  vim: set ai et sw=2 ts=2 :
