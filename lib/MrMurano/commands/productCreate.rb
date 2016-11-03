
command 'product create' do |c|
  c.syntax = %{mr product create <name>}
  c.description = %{Create a new product}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Name of product missing"
      return
    end
    name = args[0]

    ret = acc.new_product(name)
    if not ret.kind_of?(Hash) and not ret.empty? then
      acc.error "Create failed: #{ret.to_s}"
      return
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.products.select{|i| i[:label] == name}
    acc.outf ret.first[:modelId]

  end
end
#  vim: set ai et sw=2 ts=2 :
