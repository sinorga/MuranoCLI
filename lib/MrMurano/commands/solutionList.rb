require 'MrMurano/Account'
require 'terminal-table'

command 'solution list' do |c|
  c.syntax = %{mr solution list [options]}
  c.description = %{List solutions}
  c.option '--idonly', 'Only return the ids'

  c.action do |args, options|
    acc = MrMurano::Account.new
    data = acc.solutions
    if options.idonly then
      say data.map{|row| row[:apiId]}.join(' ')
    else
      busy = data.map{|r| [r[:apiId], r[:domain], r[:type], r[:sid]]}
      table = Terminal::Table.new :rows => busy, :headings => ['API ID', 'Domain', 'Type', 'SID']
      say table
    end
  end
end
alias_command :solution, 'solution list'

#  vim: set ai et sw=2 ts=2 :
