require 'uri'
require 'net/http'
require 'json'
require 'yaml'
require 'pp'
require 'MrMurano/Solution'

module MrMurano
  ##
  # User Management common things
  class UserBase < SolutionBase
    def initialize
      super
    end

    def list
      get
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    def remove(id)
      delete('/' + id.to_s)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify)
      # Roles cannot be modified, so must delete and post.
      delete('/' + remote[@itemkey]) do |request, http|
        response = http.request(request)
        case response
        when Net::HTTPSuccess
        when Net::HTTPNotFound
        else
          showHttpError(request, response)
        end
      end
      remote.reject!{|k,v| k==:synckey or k==:bundled}
      post('/', remote)
    end

    def download(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist? then
        local.open('rb') {|io| here = YAML.load(io)}
        here = [] if here == false
      end
      here.delete_if do |i|
        Hash.transform_keys_to_symbols(i)[@itemkey] == item[@itemkey]
      end
      here << item.reject{|k,v| k==:synckey}
      local.open('wb') do |io|
        io.write here.map{|i| Hash.transform_keys_to_strings(i)}.to_yaml
      end
    end

    def removelocal(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist? then
        local.open('rb') {|io| here = YAML.load(io)}
        here = [] if here == false
      end
      key = @itemkey.to_sym
      here.delete_if do |it|
        Hash.transform_keys_to_symbols(it)[key] == item[key]
      end
      local.open('wb') do|io|
        io.write here.map{|i| Hash.transform_keys_to_strings(i)}.to_yaml
      end
    end

    def tolocalpath(into, item)
      into
    end

    def localitems(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      if not from.exist? then
        warning "Skipping missing #{from.to_s}"
        return []
      end
      unless from.file? then
        warning "Cannot read from #{from.to_s}"
        return []
      end

      # MAYBE/2017-07-03: Do we care if there are duplicate keys in the yaml? See dup_count.
      here = []
      from.open { |io| here = YAML.load(io) }
      here = [] if here == false

      here.map { |i| Hash.transform_keys_to_symbols(i) }
    end
  end

  # …/role
  class Role < UserBase
    def initialize
      @solntype = 'application.id'
      #@solntype = 'product.id'
      super
      @uriparts << 'role'
      @itemkey = :role_id
    end
  end
  #SyncRoot.add('roles', Role, 'R', %{Roles})

  # …/user
  # :nocov:
  class User < UserBase
    def initialize
      # 2017-07-03: [lb] tried 'product.id' and got 403 Forbidden;
      #   And I tried 'application.id' and get() returned an empty [].
      @solntype = 'application.id'
      #@solntype = 'product.id'
      super
      @uriparts << 'user'
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify)
      # TODO figure out APIs for updating users.
      warning "Updating Users isn't working currently."
      # post does work if the :password field is set.
    end

    def synckey(item)
      item[:email]
    end
  end
  # :nocov:
  #SyncRoot.add('users', User, 'U', %{Users})
end
#  vim: set ai et sw=2 ts=2 :
