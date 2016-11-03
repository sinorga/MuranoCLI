
command 'solution create' do |c|
  c.syntax = %{mr solution create <name>}
  c.description = %{Create a new solution}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Name of solution missing"
      return
    end
    name = args[0]

    ret = acc.new_solution(name)
    if not ret.kind_of?(Hash) and not ret.empty? then
      acc.error "Create failed: #{ret.to_s}"
      return
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.solutions.select{|i| i[:domain] =~ /#{name}\./}
    acc.outf ret.first[:apiId]

  end
end
#  vim: set ai et sw=2 ts=2 :
