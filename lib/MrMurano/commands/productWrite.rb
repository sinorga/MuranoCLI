require 'MrMurano/Product'

command 'product write' do |c|
  c.syntax = %{mr product write <sn> <alias> <value> ([<alias> <value>]…)}
  c.summary = %{Write values into the product}

  c.action do |args,options|
    sn = args.shift
    prd = MrMurano::Product.new
    if (args.count % 2) != 0 then
      prd.error "Last alias is missing a value to write."
    else
      data = Hash[*args]
      ret = prd.write(sn, data)
      prd.outf(ret) do |dd|
        ret.each_pair do |k,v|
          if v == 'ok' then
            say "#{k.to_s}: #{v}"
          else
            prd.error "#{k.to_s}: #{v}"
          end
        end
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
