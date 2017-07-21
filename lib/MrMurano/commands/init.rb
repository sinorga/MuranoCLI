# Last Modified: 2017.07.14 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'erb'
require 'inflecto'
require 'rainbow'
require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/Business'
require 'MrMurano/Config'
require 'MrMurano/Config-Migrate'
require 'MrMurano/Solution-Services'
require 'MrMurano/commands/business'
require 'MrMurano/commands/solution'

def init_cmd_description
  %(

The init command helps you create a new Murano project
======================================================

Example
-------

  Create a new project in a new directory:

    #{MrMurano::EXE_NAME} init my-new-app

Example
-------

  Create a project in the current directory, or rewrite an existing project:

    cd project/path
    #{MrMurano::EXE_NAME} init

Solutions
---------

The init command configures two new Solutions for your new Murano project:

  1. An Application

     The Application is what users see.

     Use the Application to control, monitor, and consume values from products.

  2. A Product

     A Product is something that captures data and reports it to the Application.

     A Product can be a physical device connected to the Internet. It can be
     a simulator running on your local network. It can be anything that
     triggers events or supplies input data to the Application.

How it Works
------------

You will be asked to log on to your Business account.

  - To create a new Murano business account, visit:

    #{MrMurano::SIGN_UP_URL}

  - Once logged on, you can choose to store your logon token so you
    can skip this step when using Murano CLI.

After logon, name your Application, and then name your Product.

  - Please choose names that contain only lowercase letters and numbers.

    The names are used as variable names in scripts, and as domain names,
    so they cannot contain underscores, dashes, or other punctuation.

After creating the two Solutions, they will be linked.

  - Linking Solutions allows data and events to flow between the two.

    For example, a Product device generates data that will be consumed
    or processed by the Application.

The init command will pull down Product and Application services
that you can edit.

  - The services, or event handlers, let you control how data is
    processed and how your application behaves.

    Take a look at the new directories and files created in your
    Project after running init to see what services are available.

    There are many other resources that are not downloaded that
    you can also create and edit. Visit our docs site for more!

    http://docs.exosite.com/

  ).strip
end

command :init do |c|
  c.syntax = %(murano init)
  c.summary = %(The easy way to start a project)
  c.description = init_cmd_description

  c.option('--refresh', %(Ignore Business and Solution IDs found in the config))
  c.option('--purge', %(Remove Project directories and files, and recreate anew))
  c.option('--[no-]mkdirs', %(Create default directories))

  # This command can be run without a project config.
  c.project_not_required = true

  c.action do |args, options|
    options.default(refresh: false, mkdirs: true)

    acc = MrMurano::Account.instance

    c.verify_arg_count!(args, 1)
    validate_dir!(acc, args, options)

    puts('')
    say("Creating project at #{Rainbow($cfg['location.base'].to_s).underline}")
    puts('')

    # Try to import a .Solutionfile.secret.
    # NOTE/2017-06-29: .Solutionfile.secret and SolutionFile (see ProjectFile.rb)
    # are old MurCLI constructs; here we just try to migrate from the old format
    # to the new format (where config goes in .murano/config and there's an
    # explicit directory structure; the user cannot specify a different file
    # hierarchy).
    MrMurano::ConfigMigrate.new.import_secret

    # See if the config already specifies a Business ID. If not, see if the
    # config contains a username and password; otherwise, ask for them. With
    # a username and password, get the list of businesses from Murano; if
    # just one found, use that; if more than one found, ask user which one
    # to use; else, if no businesses found, spit out the new-account URL
    # and tell the user to use their browser to create a new Business.
    say("Found User #{Rainbow($cfg['user.name']).underline}")
    puts('')

    # Find and verify Business by ID (from $cfg) or by name (from --business),
    # or ask user which business to use.
    biz = business_find_or_ask(acc, ask_user: options.refresh)

    # Verify or ask user to create Solutions.
    sol_opts = {
      create_ok: true,
      update_cfg: true,
      ignore_cfg: options.refresh,
      verbose: true,
    }
    # Get/Create Application ID
    appl = solution_find_or_create(biz: biz, type: :application, **sol_opts)
    # Get/Create Product ID
    prod = solution_find_or_create(biz: biz, type: :product, **sol_opts)

    # Automatically link solutions.
    link_opts = { verbose: true }
    link_solutions(appl, prod, link_opts)

    # If no ProjectFile, then write a ProjectFile.
    write_project_file

    # Make the directory structure.
    make_directories if options.mkdirs

    # Murano creates a bunch of empty event handlers. Grab them now.
    if options.purge
      # FIXME/2017-07-02: Add test for this
      # Be destructive
      syncdown_files(delete: true, create: true, update: true)
    else
      syncdown_boilerplate
    end

    blather_success
  end

  def highlight_id(id)
    Rainbow(id).aliceblue.bright.underline
  end

  def validate_dir!(acc, args, options)
    # 2017-06-21: You can run init --dry and not have any files touched or
    # any Murano elements changed. But there's not much utility in that.
    # So maybe we should just not let users run a --dry init.
    #if $cfg['tool.dry']
    #  acc.error 'Cannot run a --dry init.'
    #  exit 2
    #end

    if args.count > 1
      acc.error('Please only specify 1 path')
      exit(2)
    end

    if args.empty?
      target_dir = Pathname.new(Dir.pwd)
    else
      target_dir = Pathname.new(args[0])
      unless Dir.exist?(target_dir.to_path)
        if target_dir.exist?
          acc.error("Target exists but is not a directory: #{target_dir.to_path}")
          exit 1
        end
        # FIXME/2017-07-02: Add test for this
        target_dir.mkpath
      end
      Dir.chdir target_dir
    end

    # The home directory already has its own .murano/ folder,
    # so we cannot create a project therein.
    if Pathname.new(Dir.pwd).realpath == Pathname.new(Dir.home).realpath
      acc.error('Cannot init a project in your HOME directory.')
      exit(2)
    end

    # Only create a new project in an empty directory,
    # or a recognized Murano CLI project.
    unless $cfg.project_exists || options.refresh
      # Get a list of files, ignoring the dot meta entries.
      files = Dir.entries(target_dir.to_path)
      files -= %w[. ..]
      unless files.empty?
        # Check for a .murano/ directory. It might be empty, which
        # is why $cfg.project_exists might have been false.
        unless files.include?(MrMurano::Config::CFG_DIR_NAME)
          acc.warning 'The project directory contains unknown files.'
          confirmed = acc.ask_yes_no('Really init project? [Y/n] ', true)
          unless confirmed
            # FIXME/2017-07-02: Add test for this
            acc.warning('abort!')
            exit 1
          end
        end
      end
    end

    target_dir
  end

  def write_project_file
    return if $project.using_projectfile
    tmpl = File.read(
      File.join(
        File.dirname(__FILE__), '..', 'template', 'projectFile.murano.erb'
      )
    )
    tmpl = ERB.new(tmpl)
    res = tmpl.result($project.data_binding)
    pr_file = $project['info.name'] + '.murano'
    say("Writing Project file to #{pr_file}")
    puts('')
    File.open(pr_file, 'w') { |io| io << res }
  end

  def make_directories
    base = $cfg['location.base']
    base = Pathname.new(base) unless base.is_a?(Pathname)
    %w[
      location.files
      location.endpoints
      location.modules
      location.eventhandlers
      location.resources
    ].each do |cfgi|
      path = $cfg[cfgi]
      path = Pathname.new(path) unless path.is_a?(Pathname)
      path = base + path
      next if path.exist?
      path = path.dirname unless path.extname.empty?
      if !$cfg['tool.dry']
        path.mkpath
      else
        say("--dry: Not creating project directory: #{path}")
      end
    end
    say('Created default directories')
    puts('')
  end

  def syncdown_boilerplate
    # Murano creates a bunch of empty event handlers. Grab them now.
    # E.g., for the product, you'll see around 20 interface_<operationId>
    # event handlers for the interaction with the application and one named device2_event.lua for receive the device data;
    # For the application, you'll see about 4 event handlers, including
    # timer_timer.lua, tsdb_exportJob.lua, and user_account.lua. The product
    # interface handlers are basic stubs, like
    #       --#EVENT interface <operationId>
    #       operation.solution_id = nil
    #       return Device2.<operationId>(operation)
    # See:
    #   sphinx-api/src/views/interface/productService.swagger.json
    # The application handlers are different, and serve as example boilerplate
    # for user to fill in.
    # Automatically pull down eventhandler stubs that Murano creates for new solutions.
    # Iterate over: MrMurano::EventHandlerSolnPrd, MrMurano::EventHandlerSolnApp.
    MrMurano::SyncRoot.each_filtered(eventhandlers: true) do |_name, _type, klass, desc|
      MrMurano::Verbose.whirly_start("Checking #{desc}...")
      begin
        syncable = klass.new
      rescue MrMurano::ConfigError => err
        acc.error("Could not fetch status for #{desc}: #{err}")
        # MAYBE: exit?
      rescue StandardError => _err
        raise
      else
        # If the user didn't make both an application and a product,
        # then some syncables won't have their IDs set.
        next unless syncable.sid?
        # Get list of changes. Leave :delete => true and :update => true so we
        # can tell if there are existing files, in which case skip the pull.
        stat = syncable.status(
          asdown: true,
          eventhandlers: true,
        )
        if stat[:todel].any? || stat[:tomod].any?
          MrMurano::Verbose.whirly_stop
          say("Skipping #{desc}: local files found")
          puts('')
        else
          stat[:toadd].each do |item|
            if !$cfg['tool.dry']
              MrMurano::Verbose.whirly_msg("Pulling item #{item[:synckey]}")
              dest = syncable.tolocalpath(syncable.location, item)
              syncable.download(dest, item)
            else
              say("--dry: Not pulling item #{item[:synckey]}")
            end
          end
        end
      end
      MrMurano::Verbose.whirly_stop
    end
  end

  def blather_success
    say('Success!')
    puts('')
    id_postfix = ' ID'
    important_ids = %w[business application product].freeze
    importantest_width = important_ids.map do |id_name|
      cfg_key = id_name + '.id'
      $cfg[cfg_key].length + id_postfix.length
    end.max # Max the map; get the length of the longest ID.
    important_ids.each do |id_name|
      # cfg_key is, e.g., 'business.id', 'product.id', 'application.id'
      cfg_key = id_name + '.id'
      next if $cfg[cfg_key].nil?
      #say "#{id_name.capitalize} ID: #{highlight_id($cfg[cfg_key])}"
      # Right-aligned:
      tmpl = format('%%%ds: %%s', importantest_width)
      # Left-aligned:
      #tmpl = format('%%-%ds: %%s', importantest_width)
      say(format(tmpl, id_name.capitalize + id_postfix, highlight_id($cfg[cfg_key])))
    end
    puts('')
  end
end
