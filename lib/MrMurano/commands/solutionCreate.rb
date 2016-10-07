
command 'solution create' do |c|
  c.syntax = %{mr solution create <name>}
  c.description = %{Create a new solution}

  c.action do |args, options|
    if args.count < 1 then
      say_error "Name of solution missing"
      return
    end
    name = args[0]

    acc = MrMurano::Account.new
    ret = acc.new_solution(name)
    if not ret.kind_of?(Hash) and not ret.empty? then
      say_error "Create failed: #{ret.to_s}"
      return
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.solutions.select{|i| i[:domain] =~ /#{name}\./}
    say ret.first[:apiId]

  end
end
#  vim: set ai et sw=2 ts=2 :
