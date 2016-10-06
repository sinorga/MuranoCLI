require 'terminal-table'

command 'product list' do |c|
  c.syntax = %{mr product list [options]}
  c.description = %{List products}
  c.option '--idonly', 'Only return the ids'

  c.action do |args, options|
    acc = MrMurano::Account.new
    data = acc.products
    if options.idonly then
      say data.map{|row| row[:pid]}.join(' ')
    else
      busy = data.map{|r| [r[:label], r[:type], r[:pid], r[:modelId]]}
      table = Terminal::Table.new :rows => busy, :headings => ['Label', 'Type', 'PID', 'ModelID']
      say table
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
