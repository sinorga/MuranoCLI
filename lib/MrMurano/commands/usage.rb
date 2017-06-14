require 'MrMurano/Solution'

command :usage do |c|
  c.syntax = %{murano usage}
# FIXME: Find other places to reword from "project"
#  c.summary = %{Get usage info for project}
#  c.description = %{Get usage info for project}
  c.summary = %{Get usage info for solution(s)}
  c.description = %{Get usage info for solution(s)}

#require 'byebug' ; byebug if true
  command_add_solution_pickers c

# FIXME: opts:
  # --type TYPE :product :application
  # --all


  c.action do |args, options|
    soln_types = MrMurano::Account::ALLOWED_TYPES
    if options.type
      soln_types = options.type
    end

    soln_ids = []
    if options.ids
      soln_ids = options.ids
    end

    soln_names = []
    if options.names
      soln_ids = options.names
    end

    solz = []

    MrMurano::Verbose::whirly_start "Fetching solutions..."
    ret = acc.solutions(options.type).select do |i|
      i[:name] == name or i[:domain] =~ /#{name}\./i
    end
    MrMurano::Verbose::whirly_stop



require 'byebug' ; byebug if true
#    options.default :type=>:all, :all=>true
#    sol = MrMurano::Solution.new
#    sol = MrMurano::Product.new
    sol = MrMurano::Application.new
    sol.outf(sol.usage) do |dd, ios|
      headers = ['', :Quota, :Daily, :Monthly, :Total]
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
      sol.tabularize({:headers=>headers, :rows=>rows}, ios)
    end
  end
end
alias_command 'usage product', 'usage', '--type', 'product'
alias_command 'usage products', 'usage', '--type', 'product'
alias_command 'usage application', 'usage', '--type', 'application'
alias_command 'usage applications', 'usage', '--type', 'application'
alias_command 'usage app', 'usage', '--type', 'application'
alias_command 'usage apps', 'usage', '--type', 'application'

#  vim: set ai et sw=2 ts=2 :
