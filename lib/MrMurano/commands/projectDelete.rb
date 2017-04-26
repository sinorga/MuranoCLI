require 'MrMurano/Account'

command 'project delete' do |c|
  c.syntax = %{murano project delete <project id>}
  c.summary = %{Delete a project}
  c.description = %{Delete a project}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "project id or name missing"
      return
    end
    name = args[0]


    # Need to convert what we got into the internal PID.
    ret = acc.products.select{|i| i.has_value?(name) or i[:domain] =~ /#{name}\./ }

    if $cfg['tool.debug'] then
      say "Matches found:"
      acc.outf ret
    end

    if ret.empty? then
      acc.error "No project matching '#{name}' found. Nothing to delete."
    else
      ret = acc.delete_product(ret.first[:sid])
      if not ret.kind_of?(Hash) and not ret.empty? then
        acc.error "Delete failed: #{ret.to_s}"
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
