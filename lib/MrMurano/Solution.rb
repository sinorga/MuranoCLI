require 'rainbow'
require 'uri'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SyncUpDown'

module MrMurano
  class SolutionBase
    def initialize(sid=nil)
      unless sid
        if !defined?(@solntype) or @solntype.nil?
          @solntype = 'application.id'
        end
        # Get the application.id or product.id.
        @sid = $cfg[@solntype]
      else
        @solntype = @solntype or 'solution.id'
        @sid = sid
      end
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

    def get(path='', query=nil, &block)
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
            if query.nil?
              query = []
            else
              query = query.dup
            end
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
            query = query.dup
            #query.push ["limit", 20]
            query.push ["offset", total-remaining]
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
    def initialize(sid=nil)
      unless sid
        if !defined?(@solntype) or @solntype.nil?
          raise "Solution subclass must set @solntype"
        end
      end
      super
    end

    def version
      get('/version')
    end

    def info(&block)
      path = ''
      query = nil
      @desc = get(path, query, &block)
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

    # Desc is from list of solutions fetched from business/<bizid>/solution/,
    # e.g., from a call to solutions(), applications(), or products().
    def desc
      @desc
    end

    def desc=(ret)
      @desc = ret
    end

    def pretty_desc(add_type=false, no_raw=false)
      # [lb] would normally put presentation code elsewhere (i.e., model
      #   classes should not be formatting output), but this seems okay.
      desc = ""
      if add_type
        desc += "#{self.type}: "
      end
      desc += "#{Rainbow(@desc[:name]).underline} <#{self.sid}> "
      if no_raw
        desc += "https://"
      end
      desc += @desc[:domain]
    end

    def sid
      # NOTE: The Solution info fetched from business/<bizid>/solutions endpoint
      #   includes the keys, :name, :sid, and :domain (see calls to solutions()).
      #   The solution details fetched from a call to Solution.get() include the
      #   keys, :name, :id, and :domain, among others. Note that the info()
      #   response does not include :type.
      @desc[:id] or @desc[:sid] or nil
    end

    def type
      # info() doesn't return :type. So get from class name, e.g.,
      # soln.class == "MrMurano::Product"
      self.class.to_s.gsub(/^.*::/, '')
    end
  end

  class Product < Solution
    def initialize(sid=nil)
      # Code path for `murano domain`.
      @solntype = 'product.id'
      super
    end
  end

  class Application < Solution
    def initialize(sid=nil)
      @solntype = 'application.id'
      super
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
