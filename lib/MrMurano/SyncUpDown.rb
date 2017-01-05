require 'pathname'
require 'tempfile'
require 'shellwords'
require 'open3'
require 'MrMurano/Config'
require 'MrMurano/hash'

module MrMurano
  ## Track what things are syncable.
  class SyncRoot
    Syncable = Struct.new(:name, :class, :type, :desc, :bydefault) do
    end

    ##
    # Add a new entry to syncable things
    # +name+:: The name to use for the long option
    # +klass+:: The class to instanciate from
    # +type+:: Single letter for short option and status listing
    # +desc+:: Summary of what this syncs.
    # +bydefault+:: Is this part of the default sync group
    #
    # returns nil
    def self.add(name, klass, type, desc, bydefault=false)
      @@syncset = [] unless defined?(@@syncset)
      @@syncset << Syncable.new(name.to_s, klass, type, desc, bydefault)
      nil
    end

    ##
    # Remove all syncables.
    def self.reset()
      @@syncset = []
    end

    ##
    # Get the list of default syncables.
    # returns array of names
    def self.bydefault
      @@syncset.select{|a| a.bydefault }.map{|a| a.name}
    end

    ##
    # Iterate over all syncables
    # +block+:: code to run on each
    def self.each(&block)
      @@syncset.each{|a| yield a.name, a.type, a.class }
    end

    ##
    # Iterate over all syncables with option arguments.
    # +block+:: code to run on each
    def self.each_option(&block)
      @@syncset.each{|a| yield "-#{a.type.downcase}", "--[no-]#{a.name}", a.desc}
    end

    ##
    # Iterate over just the selected syncables.
    # +opt+:: Options hash of which to select from
    # +block+:: code to run on each
    def self.each_filtered(opt, &block)
      self.checkSAME(opt)
      @@syncset.each do |a|
        if opt[a.name.to_sym] or opt[a.type.to_sym] then
          yield a.name, a.type, a.class
        end
      end
    end

    ## Adjust options based on all or none
    # If none are selected, select the bydefault ones.
    #
    # +opt+:: Options hash of which to select from
    #
    # returns nil
    def self.checkSAME(opt)
      if opt[:all] then
        @@syncset.each {|a| opt[a.name.to_sym] = true }
      else
        any = @@syncset.select {|a| opt[a.name.to_sym] or opt[a.type.to_sym]}
        if any.empty? then
          bydef = $cfg['sync.bydefault'].split
          @@syncset.select{|a| bydef.include? a.name }.each{|a| opt[a.name.to_sym] = true}
        end
      end

      nil
    end
  end

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
      # :nocov:
      raise "Forgotten implementation"
      # :nocov:
    end

    ## Upload local item to remote
    #
    # Children objects Must override this
    #
    # @param src Pathname: Full path of where to upload from
    # @param item Hash: The item details to upload
    # @param modify Bool: True if item exists already and this is changing it
    def upload(src, item, modify)
      # :nocov:
      raise "Forgotten implementation"
      # :nocov:
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
      {:name => path.realpath.relative_path_from(root.realpath).to_s}
    end

    ##
    # Compute the local name from remote item details
    #
    # Children objects should override this or #tolocalpath
    #
    # @param item Hash: listing details for the item.
    # @param itemkey Symbol: Key for look up.
    def tolocalname(item, itemkey)
      item[itemkey].to_s
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
        warning "Not downloading into bundled item #{synckey(item)}"
        return
      end
      local.dirname.mkpath
      id = item[@itemkey.to_sym]
      if id.nil? then
        debug "!!! Missing '#{@itemkey}', using :id instead!"
        debug ":id => #{item[:id]}"
        id = item[:id]
      end
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
      else
        warning "Skipping missing location #{@locationbase + @location}"
      end

      items.values
    end

    ##
    # Returns array of globs to search for files
    def searchFor
      %w{*.lua */*.lua}
    end

    ## Returns array of globs of files to ignore
    def ignoring
      %w{*_test.lua *_spec.lua .*}
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
      debug "#{self.class.to_s}: Getting local items from: #{from}"
      searchIn = from.to_s
      sf = searchFor.map{|i| ::File.join(searchIn, i)}
      Dir[*sf].flatten.compact.reject do |p|
        ::File.directory?(p) or ignoring.any? do |i|
          ::File.fnmatch(i,p)
        end
      end.map do |path|
        path = Pathname.new(path).realpath
        item = toRemoteItem(from, path)
        if item.kind_of?(Array) then
          item.compact.map{|i| i[:local_path] = path; i}
        elsif not item.nil? then
          item[:local_path] = path
          item
        end
      end.flatten.compact
    end

    #######################################################################
    # Methods that provide the core status/syncup/syncdown

    ##
    # Take a hash or something (a Commander::Command::Options) and return a hash
    #
    def elevate_hash(hsh)
      # Commander::Command::Options stripped all of the methods from parent
      # objects. I have not nice thoughts about that.
      begin
        hsh = hsh.__hash__
      rescue NoMethodError
        # swallow this.
      end
      # build a hash where the default is 'false' instead of 'nil'
      Hash.new(false).merge(Hash.transform_keys_to_symbols(hsh))
    end
    private :elevate_hash

    def syncup(options={})
      options = elevate_hash(options)
      itemkey = @itemkey.to_sym
      options[:asdown] = false
      dt = status(options)
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options[:delete] then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            remove(item[itemkey])
          end
        end
      end
      if options[:create] then
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path}, false)
          end
        end
      end
      if options[:update] then
        tomod.each do |item|
          verbose "Updating item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path}, true)
          end
        end
      end
    end

    def syncdown(options={})
      options = elevate_hash(options)
      options[:asdown] = true
      dt = status(options)
      into = @locationbase + @location ###
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options[:delete] then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            removelocal(dest, item)
          end
        end
      end
      if options[:create] then
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            download(dest, item)
          end
        end
      end
      if options[:update] then
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
      trmt = Tempfile.new([tolocalname(item, @itemkey)+'_remote_', '.lua'])
      tlcl = Tempfile.new([tolocalname(item, @itemkey)+'_local_', '.lua'])
      if item.has_key? :script then
        Pathname.new(tlcl.path).open('wb') do |io|
          io << item[:script]
        end
      else
        Pathname.new(tlcl.path).open('wb') do |io|
          io << item[:local_path].read
        end
      end
      df = ""
      begin
        download(Pathname.new(trmt.path), item)

        cmd = $cfg['diff.cmd'].shellsplit
        cmd << trmt.path.gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR)
        cmd << tlcl.path.gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR)

        df, _ = Open3.capture2e(*cmd)
      ensure
        trmt.close
        trmt.unlink
        tlcl.close
        tlcl.unlink
      end
      df
    end

    ## Get status of things here verses there
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
      if options[:asdown] then
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
          mrg[:diff] = dodiff(mrg) if options[:diff]
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
