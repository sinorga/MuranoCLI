
command 'product create' do |c|
  c.syntax = %{mr product create <name>}
  c.description = %{Create a new product}

  c.action do |args, options|
    if args.count < 1 then
      say_error "Name of product missing"
      return
    end
    name = args[0]

    acc = MrMurano::Account.new
    ret = acc.new_product(name)
    if not ret.kind_of?(Hash) and not ret.empty? then
      say_error "Create failed: #{ret.to_s}"
      return
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.products.select{|i| i[:label] == name}
    say ret.first[:modelId]

  end
end
#  vim: set ai et sw=2 ts=2 :
