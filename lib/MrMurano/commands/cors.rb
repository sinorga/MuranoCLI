
module MrMurano
  class Cors < SolutionBase
    def initialize
      super
      @uriparts << 'cors'
      @location = $cfg['location.cors']
    end

    def fetch()
      ret = get()
      ret[:cors]
    end

    # TODO: fill out other metheds so this could be part of sync up/down.

    ##
    # Upload CORS
    # :local path to file to push
    # :remote hash of method and endpoint path (ignored for now)
    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify=false)
      local = Pathname.new(local) unless local.kind_of? Pathname
      raise "no file" unless local.exist?

      local.open do |io|
        data = YAML.load(io)
        put('', data)
      end
    end

    def tolocalpath(into, item)
      into
    end
  end
end

command :cors do |c|
  c.syntax = %{mr cors [options]}
  c.description = %{Get or set the CORS for the solution.}
  c.option '-f','--file FILE', String, %{File to set CORS from}

  c.action do |args,options|
    sol = MrMurano::Cors.new

    if options.file then
      #set
      pp sol.upload(options.file, {})
    else
      # get
      ret = sol.fetch()
      puts ret
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
