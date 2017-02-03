require 'terminal-table'

command :account do |c|
  c.syntax = %{mr account [options]}
  c.description = %{Show things about your account.}
  c.option '--businesses', 'Get businesses for user'
  c.option '--products', 'Get products for user (needs a business)'
  c.option '--solutions', 'Get solutions for user (needs a business)'
  c.option '--idonly', 'Only return the ids'

  c.example %{List all businesses}, 'mr account --businesses'
  c.example %{List solutions}, 'mr account --solutions -c business.id=XXXXXXXX'

  c.action do |args, options|

    acc = MrMurano::Account.new

    if options.businesses then
      acc.warning "--business is deprecated; please use `mr business list` instead"
      data = acc.businesses
      if options.idonly then
        say data.map{|row| row[:bizid]}.join(' ')
      else
        busy = data.map{|row| [row[:bizid], row[:role], row[:name]]}
        table = Terminal::Table.new :rows => busy, :headings => ['Biz ID', 'Role', 'Name']
        say table
      end

    elsif options.products then
      acc.warning "--products is deprecated; please use `mr products list` instead"
      data = acc.products
      if options.idonly then
        say data.map{|row| row[:pid]}.join(' ')
      else
        busy = data.map{|r| [r[:label], r[:type], r[:pid], r[:modelId]]}
        table = Terminal::Table.new :rows => busy, :headings => ['Label', 'Type', 'PID', 'ModelID']
        say table
      end

    elsif options.solutions then
      acc.warning "--solutions is deprecated; please use `mr solutions list` instead"
      data = acc.solutions
      if options.idonly then
        say data.map{|row| row[:apiId]}.join(' ')
      else
        busy = data.map{|r| [r[:apiId], r[:domain], r[:type], r[:sid]]}
        table = Terminal::Table.new :rows => busy, :headings => ['API ID', 'Domain', 'Type', 'SID']
        say table
      end

    else
      say acc.token
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
