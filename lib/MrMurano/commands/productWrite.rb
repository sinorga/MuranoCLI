require 'MrMurano/Product'

command 'product write' do |c|
  c.syntax = %{mr product write <sn> <alias> <value> ([<alias> <value>]…)}
  c.summary = %{Write values into the product}

  c.action do |args,options|
    sn = args.shift
    if (args.count % 2) != 0 then
      say_error "Last alias is missing a value to write."
    else
      data = Hash[*args]
      prd = MrMurano::Product.new
      ret = prd.write(sn, data)
      ret.each_pair do |k,v|
        if v == 'ok' then
          say "#{k.to_s}: #{v}"
        else
          say_error "#{k.to_s}: #{v}"
        end
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
