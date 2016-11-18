require 'uri'
require 'net/http'
require 'json'
require 'pp'
require 'MrMurano/Solution'

module MrMurano
  # …/endpoint
  class Endpoint < SolutionBase
    def initialize
      super
      @uriparts << 'endpoint'
      @location = $cfg['location.endpoints']
    end

    ##
    # This gets all data about all endpoints
    def list
      get()
    end

    def fetch(id)
      ret = get('/' + id.to_s)
      aheader = (ret[:script].lines.first or "").chomp
      dheader = /^--#ENDPOINT (?i:#{ret[:method]}) #{ret[:path]}$/
      rheader = %{--#ENDPOINT #{ret[:method]} #{ret[:path]}\n}
      if block_given? then
        yield rheader unless dheader =~ aheader
        yield ret[:script]
      else
        res = ''
        res << rheader unless dheader =~ aheader
        res << ret[:script]
        res
      end
    end

    ##
    # Upload endpoint
    # :local path to file to push
    # :remote hash of method and endpoint path
    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify)
      local = Pathname.new(local) unless local.kind_of? Pathname
      raise "no file" unless local.exist?

      # we assume these are small enough to slurp.
      script = local.read
      limitkeys = [:method, :path, :script, @itemkey]
      remote = remote.select{|k,v| limitkeys.include? k }
      remote[:script] = script
#      post('', remote)
      if remote.has_key? @itemkey then
        put('/' + remote[@itemkey], remote) do |request, http|
          response = http.request(request)
          case response
          when Net::HTTPSuccess
            #return JSON.parse(response.body)
          when Net::HTTPNotFound
            verbose "\tDoesn't exist, creating"
            post('/', remote)
          else
            showHttpError(request, response)
          end
        end
      else
        verbose "\tNo itemkey, creating"
        post('/', remote)
      end
    end

    ##
    # Delete an endpoint
    def remove(id)
      delete('/' + id.to_s)
    end

    def tolocalname(item, key)
      name = ''
      name << item[:path].split('/').reject{|i|i.empty?}.join('-')
      name << '.'
      name << item[:method].downcase
      name << '.lua'
    end

    def toRemoteItem(from, path)
      # Path could be have multiple endpoints in side, so a loop.
      items = []
      path = Pathname.new(path) unless path.kind_of? Pathname
      cur = nil
      lineno=0
      path.readlines().each do |line|
        md = /--#ENDPOINT (\S+) (.*)/.match(line)
        if not md.nil? then
          # header line.
          cur[:line_end] = lineno unless cur.nil?
          items << cur unless cur.nil?
          cur = {:method=>md[1],
                 :path=>md[2],
                 :local_path=>path,
                 :line=>lineno,
                 :script=>line}
        elsif not cur.nil? and not cur[:script].nil? then
          cur[:script] << line
        end
        lineno += 1
      end
      cur[:line_end] = lineno unless cur.nil?
      items << cur unless cur.nil?
      items
    end

    def synckey(item)
      "#{item[:method].upcase}_#{item[:path]}"
    end

    def docmp(itemA, itemB)
      if itemA[:script].nil? and itemA[:local_path] then
        itemA[:script] = itemA[:local_path].read
      end
      if itemB[:script].nil? and itemB[:local_path] then
        itemB[:script] = itemB[:local_path].read
      end
      return itemA[:script] != itemB[:script]
    end

  end

  SyncRoot.add('endpoints', Endpoint, 'A', %{Endpoints}, true)
end
#  vim: set ai et sw=2 ts=2 :
