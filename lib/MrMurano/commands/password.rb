
command :password do |c|
  c.syntax = %{murano password}
  c.summary = %{About password commands}
  c.description = %{
Sub-commands for working with usernames and passwords.
  }.strip
  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end
alias_command 'password current', :config, 'user.name'

command 'password list' do |c|
  c.syntax = %{murano password list}
  c.summary = %{List the usernames with saved passwords}
  c.description = %{
List the usernames and hosts that have been saved.
  }.strip

  c.action do |args, options|
    psd = MrMurano::Passwords.new
    psd.load

    ret = psd.list
    psd.outf(ret) do |dd, ios|
      rows=[]
      dd.each_pair do |key, value|
        value.each{|v| rows << [key, v] }
      end
      psd.tabularize({
        :rows=>rows, :headers => [:Host, :Username]
      }, ios)
    end
  end
end
alias_command 'passwords list', 'password list'

command 'password set' do |c|
  c.syntax = %{murano password set <username> [<host>]}
  c.summary = %{Set password for username}
  c.description = %{
Set password for username.
  }.strip
  c.option '--password PASSWORD', String, %{The password to use}
  c.option '--from_env', %{Use password in MURANO_PASSWORD}

  c.action do |args, options|
    psd = MrMurano::Passwords.new
    psd.load

    if args.count < 1 then
      psd.error "Missing username"
      exit 1
    end

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
  c.description = %{
Delete password for username.
  }.strip

  c.action do |args, options|
    psd = MrMurano::Passwords.new
    psd.load

    if args.count < 1 then
      psd.error "Missing username"
      exit 1
    end

    username = args.shift
    host = args.shift
    host = $cfg['net.host'] if host.nil?

    psd.remove(host, username)
    psd.save
  end
end

#  vim: set ai et sw=2 ts=2 :

