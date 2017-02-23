require 'MrMurano/Solution'

command :usage do |c|
  c.syntax = %{murano usage}
  c.summary = %{Get usage info for project}
  c.description = %{Get usage info for project}

  c.action do |args,options|
    sol = MrMurano::Solution.new
    sol.outf(sol.usage) do |dd,ios|
      headers = ['', :Quota, :Daily, :Monthly, :Total]
      rows = []
      dd.each_pair do |key,value|
        quota = value[:quota] or {}
        usage = value[:usage] or {}
        rows << [key, quota[:daily], usage[:calls_daily], usage[:calls_monthly], usage[:calls_total]]
      end
      sol.tabularize({:headers=>headers,:rows=>rows}, ios)
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
