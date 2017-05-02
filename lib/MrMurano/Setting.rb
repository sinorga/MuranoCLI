require 'MrMurano/verbosing'

module MrMurano

  class Setting
    include Verbose

    SERVICE_MAP = {
      'Device2' => 'Gateway',
    }.freeze

    ## Map service names into actual class names.
    #
    # Some of the service names have changed over time and nolonger match the class
    # names that implement them.  This maps them back, as well as correcting casing.
    #
    # @param service [String] User facing service name
    # @return [String] Internal class name for service
    def mapservice(service)
      service = service.to_s.downcase
      SERVICE_MAP.each_pair do |k, v|
        if service == k.downcase or service == v.downcase then
          return v
        end
      end
      return service.sub(/(.)(.*)/){"#{$1.upcase}#{$2.downcase}"}
    end

    def read(service, setting)
      begin
        debug %{Looking up class "MrMurano::#{mapservice(service)}::Settings"}
        gb = Object::const_get("MrMurano::#{mapservice(service)}::Settings").new
        meth = setting.to_sym
        debug %{Looking up method "#{meth}"}
        if gb.respond_to? meth then
          return gb.__send__(meth)

        else
          error "Unknown setting '#{setting}' on '#{service}'"
        end

      rescue NameError => e
        error "No Settings on \"#{service}\""
        if $cfg['tool.debug'] then
          error e.message
          error e.to_s
        end
      end
    end

    def write(service, setting, value)
      begin
        debug %{Looking up class "MrMurano::#{mapservice(service)}::Settings"}
        gb = Object::const_get("MrMurano::#{mapservice(service)}::Settings").new
        meth = "#{setting}=".to_sym
        debug %{Looking up method "#{meth}"}
        if gb.respond_to? meth then
          return gb.__send__(meth, value)

        else
          error "Unknown setting '#{setting}' on '#{service}'"
        end

      rescue NameError => e
        error "No Settings on \"#{service}\""
        if $cfg['tool.debug'] then
          error e.message
          error e.to_s
        end
      end
    end
  end

end

#  vim: set ai et sw=2 ts=2 :

