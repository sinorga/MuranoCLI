require 'MrMurano/Account'

command 'login' do |c|
  c.syntax = %{murano login}
  c.summary = %{Log into Murano}
  c.description = %{
Log into Murano

If you are having trouble logging in, try deleting the saved password first.

  `murano password delete <username>`
  }.strip
  c.option '--show-token', %{Shows the API token}

  c.action do |args, options|
    acc = MrMurano::Account.new
    ret = acc.token
    say ret if options.show_token
  end
end

#  vim: set ai et sw=2 ts=2 :

