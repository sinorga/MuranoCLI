require 'MrMurano/Solution'

module MrMurano
  class Cors < SolutionBase
    def initialize
      super
      @uriparts << 'cors'
      @location = $cfg['location.cors']
    end

    def list()
      [fetch()]
    end

    def fetch(id=nil)
      ret = get()
      ret[:cors]
    end

    def remove(id)
      # Not really anything to do here. Return to defaults? maybe?
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

#    def download(local, item)
#    end
#
#    def removelocal(dest, item)
#    end
#
#    def localitems(from)
#      from = Pathname.new(from) unless from.kind_of? Pathname
#      if not from.exist? then
#        say_warning "Skipping missing #{from.to_s}"
#        return []
#      end
#      unless from.file? then
#        say_warning "Cannot read from #{from.to_s}"
#        return []
#      end
#
#    end

  end
end

#  vim: set ai et sw=2 ts=2 :
