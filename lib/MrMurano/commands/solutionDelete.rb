require 'MrMurano/Account'

command 'solution delete' do |c|
  c.syntax = %{mr solution delete <solution id>}
  c.description = %{Delete a solution}

  c.action do |args, options|
    if args.count < 1 then
      say_error "Solution id or name missing"
      return
    end
    name = args[0]

    acc = MrMurano::Account.new

    # Need to convert what we got into the internal PID.
    ret = acc.solutions.select{|i| i.has_value?(name) or i[:domain] =~ /#{name}\./ }

    if $cfg['tool.debug'] then
      say "Matches found:"
      pp ret
    end

    if ret.empty? then
      say_error "No solution matching '#{name}' found. Nothing to delete."
    else
      ret = acc.delete_solution(ret.first[:sid])
      if not ret.kind_of?(Hash) and not ret.empty? then
        say_error "Delete failed: #{ret.to_s}"
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
