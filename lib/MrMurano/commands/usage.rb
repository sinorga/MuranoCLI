require 'MrMurano/Solution'

command :usage do |c|
  c.syntax = %{murano usage}
  c.summary = %{Get usage info for solution(s)}
  c.description = %{
Get usage info for solution(s).
  }.strip
  # Add the flags: --types, --ids, --names, --[no]-header.
  command_add_solution_pickers c

  c.action do |args, options|
    solz = must_fetch_solutions(options)

    solsages = []
    MrMurano::Verbose::whirly_start "Fetching usage..."
    solz.each do |soln|
      solsages += [[soln, soln.usage,],]
    end
    MrMurano::Verbose::whirly_stop

    solsages.each do |soln, usage|
      soln.outf(usage) do |dd, ios|
        if options.header
          ios.puts "#{soln.type}: #{soln.pretty_desc}"
        end
        headers = ['', :Quota, :Daily, :Monthly, :Total,]
        rows = []
        dd.each_pair do |key, value|
          quota = value[:quota] or {}
          usage = value[:usage] or {}
          rows << [
            key,
            quota[:daily],
            usage[:calls_daily],
            usage[:calls_monthly],
            usage[:calls_total],
          ]
        end
        soln.tabularize({:headers=>headers, :rows=>rows}, ios)
      end
    end

  end
end
alias_command 'usage product', 'usage', '--type', 'product'
alias_command 'usage products', 'usage', '--type', 'product'
alias_command 'usage prod', 'usage', '--type', 'product'
alias_command 'usage prods', 'usage', '--type', 'product'
alias_command 'usage application', 'usage', '--type', 'application'
alias_command 'usage applications', 'usage', '--type', 'application'
alias_command 'usage app', 'usage', '--type', 'application'
alias_command 'usage apps', 'usage', '--type', 'application'

#  vim: set ai et sw=2 ts=2 :

