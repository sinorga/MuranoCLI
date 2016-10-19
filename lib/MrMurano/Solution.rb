require 'uri'
require 'net/http'
require 'json'
require 'tempfile'
require 'shellwords'
require 'pp'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'

module MrMurano
  class SolutionBase
    # This might also be a valid ProductBase.
    def initialize
      @sid = $cfg['solution.id']
      raise "No solution!" if @sid.nil?
      @uriparts = [:solution, @sid]
      @itemkey = :id
      @locationbase = $cfg['location.base']
      @location = nil
    end

    include Http
    include Verbose

    def endPoint(path='')
      parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
      s = parts.map{|v| v.to_s}.join('/')
      URI(s + path.to_s)
    end
    # …

    ##
    # Compute a remote item hash from the local path
    # @param root Pathname: Root path for this resource type from config files
    # @param path Pathname: Path to local item
    # @return Hash: hash of the details for the remote item for this path
    def toRemoteItem(root, path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      root = Pathname.new(root) unless root.kind_of? Pathname
      {:name => path.relative_path_from(root).to_s}
    end

    ##
    # Compute the local name from remote item details
    # @param item Hash: listing details for the item.
    # @param itemkey Symbol: Key for look up.
    def tolocalname(item, itemkey)
      item[itemkey]
    end

    ##
    # Compute the local path from the listing details
    #
    # If there is already a matching local item, some of its details are also in
    # the item hash.
    #
    # @param into Pathname: Root path for this resource type from config files
    # @param item Hash: listing details for the item.
    # @return Pathname: path to save (or merge) remote item into
    def tolocalpath(into, item)
      return item[:local_path] if item.has_key? :local_path
      itemkey = @itemkey.to_sym
      name = tolocalname(item, itemkey)
      raise "Bad key(#{itemkey}) for #{item}" if name.nil?
      name = Pathname.new(name) unless name.kind_of? Pathname
      name = name.relative_path_from(Pathname.new('/')) if name.absolute?
      into + name
    end

    ##
    # So, for bundles this needs to look at all the places and build up the mered
    # stack of local items.
    #
    # Which means it needs the from to be split into the base and the sub so we can
    # inject bundle directories.

    ##
    # Get a list of local items.
    #
    # This collects items in the project and all bundles.
    def locallist()
      # so. if @locationbase/bundles exists
      #  gather and merge: @locationbase/bundles/*/@location
      # then merge @locationbase/@location
      #

      bundleDir = $cfg['location.bundles'] or 'bundles'
      bundleDir = 'bundles' if bundleDir.nil?
      items = {}
      if (@locationbase + bundleDir).directory? then
        (@locationbase + bundleDir).children.sort.each do |bndl|
          if (bndl + @location).exist? then
            verbose("Loading from bundle #{bndl.basename}")
            bitems = localitems(bndl + @location)
            bitems.map!{|b| b[:bundled] = true; b} # mark items from bundles.


            # use synckey for quicker merging.
            bitems.each { |b| items[synckey(b)] = b }
          end
        end
      end
      if (@locationbase + @location).exist? then
        bitems = localitems(@locationbase + @location)
        # use synckey for quicker merging.
        bitems.each { |b| items[synckey(b)] = b }
      end

      items.values
    end

    ##
    # Get a list of local items rooted at #from
    def localitems(from)
      from.children.map do |path|
        if path.directory? then
          # TODO: look for definition. ( ?.rockspec? ?mr.modules? ?mr.manifest? )
          # Lacking definition, find all *.lua but not *_test.lua
          # This specifically and intentionally only goes one level deep.
          path.children
        else
          path
        end
      end.flatten.compact.reject do |path|
        path.fnmatch('*_test.lua') or path.basename.fnmatch('.*')
      end.select do |path|
        path.extname == '.lua'
      end.map do |path|
        # sometimes this is a name, sometimes it is an item.
        # do I want to keep that? NO.
        name = toRemoteItem(from, path)
        unless name.nil? then
          name[:local_path] = path
          name
        end
      end.flatten.compact
    end

    def synckey(item)
      key = @itemkey.to_sym
      item[key]
    end

    def download(local, item)
      if item[:bundled] then
        say_warning "Not downloading into bundled item #{synckey(item)}"
        return
      end
      local.dirname.mkpath
      id = item[@itemkey.to_sym]
      local.open('wb') do |io|
        fetch(id) do |chunk|
          io.write chunk
        end
      end
    end

    def removelocal(dest, item)
      dest.unlink
    end

    def syncup(options=Commander::Command::Options.new)
      itemkey = @itemkey.to_sym
      options.asdown=false
      dt = status(options)
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options.delete then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            remove(item[itemkey])
          end
        end
      end
      if options.create then
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path})
          end
        end
      end
      if options.update then
        tomod.each do |item|
          verbose "Updating item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path})
          end
        end
      end
    end

    # FIXME this still needs the path passed in.
    # Need to think some more on how syncdown works with bundles.
    def syncdown(options=Commander::Command::Options.new)
      options.asdown = true
      dt = status(options)
      into = @locationbase + @location ###
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options.delete then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            removelocal(dest, item)
          end
        end
      end
      if options.create then
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            download(dest, item)
          end
        end
      end
      if options.update then
        tomod.each do |item|
          verbose "Updating item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            download(dest, item)
          end
        end
      end
    end

    ##
    # True if itemA and itemB are different
    def docmp(itemA, itemB)
      true
    end

    def dodiff(item)
      tfp = Tempfile.new([tolocalname(item, @itemkey), '.lua'])
      df = ""
      begin
        download(Pathname.new(tfp.path), item)

        cmd = $cfg['diff.cmd'].shellsplit
        cmd << tfp.path
        cmd << item[:local_path].to_s

        IO.popen(cmd) {|io| df = io.read }
      ensure
        tfp.close
        tfp.unlink
      end
      df
    end

    def status(options=Commander::Command::Options.new)
      there = list()
      here = locallist()
      itemkey = @itemkey.to_sym

      therebox = {}
      there.each do |item|
        item = Hash.transform_keys_to_symbols(item)
        item[:synckey] = synckey(item)
        therebox[ item[:synckey] ] = item
      end
      herebox = {}
      here.each do |item|
        item = Hash.transform_keys_to_symbols(item)
        item[:synckey] = synckey(item)
        herebox[ item[:synckey] ] = item
      end
      toadd = []
      todel = []
      tomod = []
      unchg = []
      if options.asdown then
        todel = (herebox.keys - therebox.keys).map{|key| herebox[key] }
        toadd = (therebox.keys - herebox.keys).map{|key| therebox[key] }
      else
        toadd = (herebox.keys - therebox.keys).map{|key| herebox[key] }
        todel = (therebox.keys - herebox.keys).map{|key| therebox[key] }
      end
      (herebox.keys & therebox.keys).each do |key|
        # Want here to override there except for itemkey.
        mrg = herebox[key].reject{|k,v| k==itemkey}
        mrg = therebox[key].merge(mrg)
        if docmp(herebox[key], therebox[key]) then
          mrg[:diff] = dodiff(mrg) if options.diff
          tomod << mrg
        else
          unchg << mrg
        end
      end
      { :toadd=>toadd, :todel=>todel, :tomod=>tomod, :unchg=>unchg }
    end
  end

  class Solution < SolutionBase
    def version
      get('/version')
    end

    def info
      get()
    end

    def list
      get('/')
    end

    def log
      get('/logs')
    end

  end

end

#  vim: set ai et sw=2 ts=2 :
