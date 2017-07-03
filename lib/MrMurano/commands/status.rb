# Last Modified: 2017.07.03 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/verbosing'

command :status do |c|
  c.syntax = %(murano status [options] [filters])
  c.summary = %(Get the status of files)
  c.description = %(
Get the status of files.

Compares the local project against what is up in Murano, showing a summary
of what things are new or changed.

When --diff is passed, for items that have changes, the remote item and
local item are passed to a diff tool and that output is included.

The diff tool and options to it can be set with the config key 'diff.cmd'.

Filters allow for selecting a subset of items to check based on patterns.

File glob filters can be used to select local files. The glob is compared
with the full file path.

Each item type also supports specific filters. These always start with #.
Endpoints can be selected with a "#<method>#<path glob>" pattern.
  ).gsub(/^ +/, '').strip
  c.option '--all', 'Check everything'

  # Load options to control which things to status
  MrMurano::SyncRoot.each_option do |s, l, d|
    c.option s, l, d
  end

  c.option '--[no-]asdown', %(Report as if syncdown instead of syncup)
  c.option '--[no-]diff', %(For modified items, show a diff)
  c.option '--[no-]grouped', %(Group all adds, deletes, and mods together)
  c.option '--[no-]showall', %(List unchanged as well)

  c.action do |args, options|
    options.default delete: true, create: true, update: true, diff: false, grouped: true

    def fmtr(item)
      if item.key? :local_path
        lp = item[:local_path].relative_path_from(Pathname.pwd).to_s
        if item.key?(:line) && item[:line].positive?
          return "#{lp}:#{item[:line]}"
        end
        lp
      else
        item[:synckey]
      end
    end

    def pretty(ret, options)
      pretty_group_header(ret[:toadd], 'Only on local machine', 'new locally', options.grouped)
      ret[:toadd].each { |item| say " + #{item[:pp_type]}  #{highlight_chg(fmtr(item))}" }

      pretty_group_header(ret[:todel], 'Only on remote server', 'new remotely', options.grouped)
      ret[:todel].each { |item| say " - #{item[:pp_type]}  #{highlight_del(fmtr(item))}" }

      pretty_group_header(ret[:tomod], 'Items that differ', 'that differs', options.grouped)
      ret[:tomod].each do |item|
        say " M #{item[:pp_type]}  #{highlight_chg(fmtr(item))}"
        say item[:diff] if options.diff
      end

      unless ret[:skipd].empty?
        pretty_group_header(ret[:skipd], 'Items without a solution', 'without a solution', options.grouped)
        ret[:skipd].each { |item| say " - #{item[:pp_type]}  #{highlight_del(fmtr(item))}" }
      end

      return unless options.showall
      say 'Unchanged:' if options.grouped
      ret[:unchg].each { |item| say "   #{item[:pp_type]}  #{fmtr(item)}" }
    end

    def pretty_group_header(group, header_any, header_empty, grouped)
      return unless grouped
      if !group.empty?
        say "#{header_any}:"
      else
        say "Nothing #{header_empty}"
      end
    end

    def highlight_chg(msg)
      Rainbow(msg).green.bright
    end

    def highlight_del(msg)
      Rainbow(msg).red.bright
    end

    @grouped = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [] }
    def gmerge(ret, type, options)
      if options.grouped
        out = @grouped
      else
        out = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [] }
      end

      %i[toadd todel tomod unchg skipd].each do |kind|
        ret[kind].each do |item|
          item = item.to_h
          item[:pp_type] = type
          out[kind] << item
        end
      end

      pretty(out, options) unless options.grouped
    end

    MrMurano::SyncRoot.each_filtered(options.__hash__) do |_name, type, klass, desc|
      MrMurano::Verbose.whirly_msg "Fetching #{desc}..."
      begin
        syncable = klass.new
      rescue MrMurano::ConfigError => err
        MrMurano::Verbose.error "Could not fetch status for #{desc}: #{err}"
      rescue StandardError => _err
        raise
      else
        # Different syncables use different solution types, so if a
        # certain solution doesn't exist, its syncables won't have an sid.
        if syncable.sid?
          ret = syncable.status(options, args)
        else
          ret = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [] }
          ret[:skipd] << { synckey: desc }
        end
        gmerge(ret, type, options)
      end
    end
    MrMurano::Verbose.whirly_stop

    pretty(@grouped, options) if options.grouped
  end
end

alias_command :diff, :status, '--diff', '--no-grouped'

