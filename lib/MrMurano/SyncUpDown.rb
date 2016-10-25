require 'pathname'
require 'tempfile'
require 'shellwords'
require 'MrMurano/Config'
require 'MrMurano/hash'

module MrMurano
  module SyncUpDown
    #######################################################################
    # Methods that must be overridden

    ##
    # Get a list of remote items.
    #
    # Children objects Must override this
    #
    # @return Array: of Hashes of item details
    def list()
      []
    end

    ## Remove remote item
    #
    # Children objects Must override this
    #
    # @param itemkey String: The identifying key for this item
    def remove(itemkey)
      raise "Forgotten implementation"
    end

    ## Upload local item to remote
    #
    # Children objects Must override this
    #
    # @param src Pathname: Full path of where to upload from
    # @param item Hash: The item details to upload
    def upload(src, item)
      raise "Forgotten implementation"
    end

    ##
    # True if itemA and itemB are different
    #
    # Children objects must override this
    #
    def docmp(itemA, itemB)
      true
    end

    #
    #######################################################################

    #######################################################################
    # Methods that could be overriden

    ##
    # Compute a remote item hash from the local path
    #
    # Children objects should override this.
    #
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
    #
    # Children objects should override this or #tolocalpath
    #
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
    # Children objects should override this or #tolocalname
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

    ## Get the key used to quickly compare two items
    #
    # Children objects should override this if synckey is not @itemkey
    #
    # @param item Hash: The item to get a key from
    # @returns Object: The object to use a comparison key
    def synckey(item)
      key = @itemkey.to_sym
      item[key]
    end

    ## Download an item into local
    #
    # Children objects should override this or implement #fetch()
    #
    # @param local Pathname: Full path of where to download to
    # @param item Hash: The item to download
    def download(local, item)
      if item[:bundled] then
        say_warning "Not downloading into bundled item #{synckey(item)}"
        # FIXME don't use say_warning
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

    ## Remove local reference of item
    #
    # Children objects should override this if move than just unlinking the local
    # item.
    #
    # @param dest Pathname: Full path of item to be removed
    # @param item Hash: Full details of item to be removed
    def removelocal(dest, item)
      dest.unlink
    end

    #
    #######################################################################


    ##
    # So, for bundles this needs to look at all the places and build up the mered
    # stack of local items.
    #
    # Which means it needs the from to be split into the base and the sub so we can
    # inject bundle directories.

    ##
    # Get a list of local items.
    #
    # Children should never need to override this.  Instead they should override
    # #localitems
    #
    # This collects items in the project and all bundles.
    # @return Array: of Hashes of items
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
    #
    # Children rarely need to override this. Only when the locallist is not a set
    # of files in a directory will they need to override it.
    #
    # @param from Pathname: Directory of items to scan
    # @return Array: of Hashes of item details
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

    #######################################################################
    # Methods that provide the core status/syncup/syncdown

    def elevate_hash(hsh)
      if hsh.kind_of?(Hash) then
        hsh = Hash.transform_keys_to_symbols(hsh)
        hsh.define_singleton_method(:method_missing) do |mid,*args|
          if mid.to_s.match(/^(.+)=$/) then
            self[$1.to_sym] = args.first
          else
            self[mid]
          end
        end
      end
      hsh
    end
    private :elevate_hash

    def syncup(options={})
      options = elevate_hash(options)
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

    def syncdown(options={})
      options = elevate_hash(options)
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

    ## Call external diff tool on item
    # WARNING: This will download the remote item to do the diff.
    # @param item Hash: The item to get a diff of
    # @return String: The diff output
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

    def status(options={})
      options = elevate_hash(options)
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
end
#  vim: set ai et sw=2 ts=2 :
