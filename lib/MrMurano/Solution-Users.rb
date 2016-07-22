require 'uri'
require 'net/http'
require 'json'
require 'yaml'
require 'pp'

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
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
        end
      end
      post('/', remote)
    end

    def download(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist? then
        local.open('rb') {|io| here = YAML.load(io)}
      end
      here << item
      local.open('wb') {|io| io.write here.to_yaml }
    end

    def removelocal(dest, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist? then
        local.open('rb') {|io| here = YAML.load(io)}
      end
      key = @itemkey.to_sym
      here.delete_if do |it|
        it[key] == item[key]
      end
      local.open('wb') {|io| io.write here.to_yaml }
    end

    def tolocalpath(into, item)
      into
    end

    def locallist(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      if not from.exist? then
        say_warning "Skipping missing #{from.to_s}"
        return []
      end
      unless from.file? then
        say_warning "Cannot read from #{from.to_s}"
        return []
      end
      key = @itemkey.to_sym

      here = {}
      from.open {|io| here = YAML.load(io) }

      here
    end
  end

  # …/role
  class Role < UserBase
    def initialize
      super
      @uriparts << 'role'
      @itemkey = :role_id
    end
  end

  # …/user
  class User < UserBase
    def initialize
      super
      @uriparts << 'user'
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
end
#  vim: set ai et sw=2 ts=2 :
