require 'MrMurano/Account'

command 'product delete' do |c|
  c.syntax = %{mr product delete <product>}
  c.summary = %{Delete a product}
  c.description = %{Delete a product}

  c.action do |args, options|
    if args.count < 1 then
      say_error "Product id or name missing"
      return
    end
    name = args[0]

    acc = MrMurano::Account.new

    # Need to convert what we got into the internal PID.
    ret = acc.products.select{|i| i.has_value? name }

    if $cfg['tool.debug'] then
      say "Matches found:"
      acc.outf ret
    end

    if ret.empty? then
      say_error "No product matching '#{name}' found. Nothing to delete."
    else
      ret = acc.delete_product(ret.first[:pid])
      if not ret.kind_of?(Hash) and not ret.empty? then
        say_error "Delete failed: #{ret.to_s}"
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
