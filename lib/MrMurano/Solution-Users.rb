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
    def list()
      get()
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    def remove(id)
      delete('/' + id.to_s)
    end

    def upload(local, remote)
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

    def removelocal(dest, item)
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
        say_warning "Skipping missing #{from.to_s}"
        return []
      end
      unless from.file? then
        say_warning "Cannot read from #{from.to_s}"
        return []
      end

      here = []
      from.open {|io| here = YAML.load(io) }
      here = [] if here == false

      here.map{|i| Hash.transform_keys_to_symbols(i)}
    end
  end

  # …/role
  class Role < UserBase
    def initialize
      super
      @uriparts << 'role'
      @itemkey = :role_id
      @location = $cfg['location.roles']
    end
  end
  SyncRoot.add('roles', Role, 'R', %{Roles})

  # …/user
  class User < UserBase
    def initialize
      super
      @uriparts << 'user'
      @location = $cfg['location.users']
    end

    def upload(local, remote)
      # TODO figure out APIs for updating users.
      say_warning "Updating Users isn't working currently."
      # post does work if the :password field is set.
    end

    def synckey(item)
      item[:email]
    end
  end
  SyncRoot.add('users', User, 'U', %{Users})
end
#  vim: set ai et sw=2 ts=2 :
