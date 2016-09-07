
module MrMurano
  class Cors < SolutionBase
    def initialize
      super
      @uriparts << 'cors'
      @location = $cfg['location.cors']
    end
  end
end

command :cors do |c|
  c.syntax = %{mr cors [<new cors>|-]}
  c.description = %{Get or set the CORS for the solution.}

  c.action do |args,options|
    sol = MrMurano::Cors.new
    if args.count == 0 then
      # get
      ret = sol.get()
      pp ret
    else
      # set
      if args.first == '-' then
      else
        data = args.join(' ')
      end
      ret = sol.put('', data)
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
