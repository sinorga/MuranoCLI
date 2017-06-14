require 'uri'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SyncUpDown'

module MrMurano
  class SolutionBase
    def initialize
      if !defined?(@solntype) or @solntype.nil?
        @solntype = 'application.id'
      end
      # Get the application.id or product.id.
      @sid = $cfg[@solntype]
      # Maybe raise "No application!" or "No product!".
      raise MrMurano::ConfigError.new("No #{/(.*).id/.match(@solntype)[1]}!") if @sid.nil?
      @uriparts = [:solution, @sid]
      @itemkey = :id
      @project_section = nil
    end

    include Http
    include Verbose

    ## Generate an endpoint in Murano
    # Uses the uriparts and path
    # @param path String: any additional parts for the URI
    # @return URI: The full URI for this enpoint.
    def endPoint(path='')
      parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
      s = parts.map{|v| v.to_s}.join('/')
      URI(s + path.to_s)
    end
    # …

    def get(*args)
      aggregate = nil
      total = nil
      remaining = -1
      while remaining != 0 do
        ret = super
        if ret.nil?
          warning "No solution with ID: #{@sid}"
          exit 1
        end
        # Pagination: Check if more data.
        if ret.is_a?(Hash) and ret.has_key?(:total) and ret.has_key?(:items)
          if total.nil?
            total = ret[:total]
            remaining = total - ret[:items].length
            # The response also includes a hint of how to get the next page.
            #   ret[:next] == "/api/v1/eventhandler?query={\
            #     \"solution_id\":\"XXXXXXXXXXXXXXXX\"}&limit=20&offset=20"
            # But note that the URL we use is a little different
            #   https://bizapi.hosted.exosite.io/api:1/solution/XXXXXXXXXXXXXXXXX/eventhandler
            if args[1].nil?
              args[1] = []
            end
            query = args[1].dup
          else
            if total != ret[:total]
              warning "Unexpected: subsequence :total not total: #{ret[:total]} != #{total}"
            end
            remaining -= ret[:items].length
            if remaining <= 0
              if remaining != 0
                warning "Unexpected: remaining count not zero but ‘#{total}’"
                remaining = 0
              end
            end
          end
          if remaining > 0
            args[1] = query.dup
            #args[1].push ["limit", 20]
            args[1].push ["offset", total-remaining]
          end
          if aggregate.nil?
            aggregate = ret
          else
            aggregate[:items].concat ret[:items]
          end
        else
          aggregate = ret
          remaining = 0
        end
      end
      aggregate
    end

    include SyncUpDown
  end

  class Solution < SolutionBase
    def initialize
      if !defined?(@solntype) or @solntype.nil?
        raise "Solution subclass must set @solntype"
      end
      super
    end

    def version
      get('/version')
    end

    def info
      get()
    end

    def list
      get('/')
    end

    def usage
      get('/usage')
    end

    def log
      get('/logs')
    end
  end

  class Product < Solution
    def initialize
      # Code path for `murano domain`.
      @solntype = 'product.id'
      super
    end
  end

  class Application < Solution
    def initialize
      @solntype = 'application.id'
      super
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
