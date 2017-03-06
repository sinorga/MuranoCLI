require 'MrMurano/Solution'
command :domain do |c|
  c.syntax = %{murano domain}
  c.summary = %{Print the domain for this solution}
  c.option '--[no-]raw', %{Don't add scheme}
  c.action do |args,options|
    options.default :raw=>true
    sol = MrMurano::Solution.new
    ret = sol.info()
    if options.raw then
      say ret[:domain]
    else
      say "https://#{ret[:domain]}"
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
