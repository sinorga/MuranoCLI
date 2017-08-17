# Last Modified: 2017.08.16 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/Business'
require 'MrMurano/ReCommander'

MSG_BUSINESSES_NONE_FOUND = 'No businesses found' if !defined? MSG_BUSINESSES_NONE_FOUND

# *** Base business command help.
# -------------------------------

command :business do |c|
  c.syntax = %(murano business)
  c.summary = %(About business)
  c.description = %(
Commands for working with businesses.
  ).strip
  c.project_not_required = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end
alias_command 'businesses', 'business'

# *** Common business command options.
# ------------------------------------

def cmd_business_add_options(c)
# MAYBE/2017-08-15: Rename to --id-only.
  c.option '--idonly', 'Only return the IDs'

  c.option '--[no-]brief', 'Show fewer fields: only Business ID and name'

  # FIXME: Move -o to a file with --json, etc.; smells like a universal output format.
  c.option '-o', '--output FILE', 'Download to file instead of STDOUT'
end

def cmd_options_add_id_and_name(c)
  c.option '--id', 'Specified argument is an ID'
  c.option '--name', 'Specified argument is a name'
end

def cmd_defaults_id_and_name(options)
  if !options.id.nil? && !options.name.nil?
    MrMurano::Verbose.error('Please only --id or --name but not both')
    exit 1
  end
end

def cmd_verify_args_and_id_or_name!(args, options)
  if !args.any? && (options.id || options.name)
    MrMurano::Verbose.warning(
      'The --id and --name options only apply when specifying a business name or ID.'
    )
    exit 1
  end
end

def cmd_option_business_pickers(c)
  c.option('--business-id ID', String, %(ID of Murano Business to use))
  c.option('--business-name NAME', String, %(Name of Murano Business to use))
  c.option('--business BUSINESS', String, %(Name or ID of Murano Business to use))
end

def any_business_pickers?(options)
  num_ways = 0
  num_ways += 1 unless options.business_id.to_s.empty?
  num_ways += 1 unless options.business_name.to_s.empty?
  num_ways += 1 unless options.business.to_s.empty?
  #if num_ways > 1
  #  MrMurano::Verbose.error(
  #    'Please specify only one of: --business, --business-id, or --business-name'
  #  )
  #  exit 1
  #end
  num_ways.length > 0
end

# *** Business commands: list and find.
# -------------------------------------

command 'business list' do |c|
  c.syntax = %(murano business list [--options])
  c.summary = %(List businesses)
  c.description = %(
List businesses.
  ).strip
  c.project_not_required = true

  cmd_business_add_options(c)

  c.action do |args, options|
    c.verify_arg_count!(args)
    cmd_business_find_and_output(args, options)
  end
end
alias_command 'businesses list', 'business list'

command 'business find' do |c|
  c.syntax = %(murano business find [--options] [<name-or-ID,...>])
  c.summary = %(Find business by name or ID)
  c.description = %(
Find business by name or ID.
  ).strip
  c.project_not_required = true

  cmd_business_add_options(c)

  # Add --business/-id/-name options.
  cmd_option_business_pickers(c)

  # Add --id and --name options.
  cmd_options_add_id_and_name(c)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    cmd_defaults_id_and_name(options)
    if !args.any? && !any_business_pickers?(options)
      MrMurano::Verbose.error('What would you like to find?')
      exit 1
    end
    cmd_business_find_and_output(args, options)
  end
end

# *** Business actions helpers.
# -----------------------------

def business_find_or_ask!(acc, options)
  #any_business_pickers?(options)

  match_bid = options.business_id
  match_name = options.business_name
  match_fuzzy = options.business

  if !match_bid.to_s.empty? || !match_name.to_s.empty? || !match_fuzzy.to_s.empty?
    biz = business_locate!(acc, match_bid, match_name, match_fuzzy)
  elsif !options.find_only
    ask_user = options.refresh
    biz = business_from_config unless ask_user
    biz = businesses_ask_which(acc) if biz.nil?
  end

  match_bid = $cfg.set('business.id', nil, :internal)
  match_name = $cfg.set('business.name', nil, :internal)
  match_fuzzy = $cfg.set('business.fuzzy', nil, :internal)

  biz
end

def business_locate!(acc, match_bid, match_name, match_fuzzy)
  biz = nil
  bizes = acc.businesses(bid: match_bid, name: match_name, fuzzy: match_fuzzy)
  if bizes.count == 1
    biz = bizes.first
    say("Found business #{biz.pretty_name_and_id}")
    puts('')
  elsif bizes.count > 1
    acc.error('More than one matching business was found. Please be more specific.')
    exit(1)
  else
    acc.error('No matching business was found. Please try again.')
    #say('Please visit Exosite.com to view your account and to create a business:')
    #say("  #{MrMurano::SIGN_UP_URL}")
    exit(1)
  end
  biz
end

def business_from_config
  # By default, creating a new Business object loads its ID from the config.
  biz = MrMurano::Business.new
  unless biz.bid.empty?
    # Verify that the business exists.
    MrMurano::Verbose.whirly_start('Verifying Business...')
    biz.overview
    MrMurano::Verbose.whirly_stop
    if biz.valid?
      say("Found Business #{biz.pretty_name_and_id}")
    else
      say("Could not find Business ‘#{biz.bid}’ referenced in the config")
    end
    puts('')
  end
  biz if biz.valid?
end

def businesses_ask_which(acc)
  biz = nil
  bizes = acc.businesses
  if bizes.count == 1
    biz = bizes.first
    say("This user has one business. Using #{biz.pretty_name_and_id}")
  elsif bizes.count.zero?
    MrMurano::Verbose.warning('This user has not created any businesses.')
    say('Please log on to exosite.com to create a free account. Visit:')
    say("  #{MrMurano::SIGN_UP_URL}")
    exit 3
  else
    choose do |menu|
      menu.prompt = 'Please select the Business to use:'
      menu.flow = :columns_across
      bizes.sort_by(&:name).each do |choice|
        menu.choice(choice.name) do
          biz = choice
        end
      end
    end
  end
  puts('')
  biz
end

def cmd_business_find_and_output(args, options)
  cmd_verify_args_and_id_or_name!(args, options)
  acc = MrMurano::Account.instance
  bizz = cmd_business_find_businesses(acc, args, options)
  if bizz.empty? && !options.idonly
    MrMurano::Verbose.error(MSG_BUSINESSES_NONE_FOUND)
    exit 0
  end
  cmd_business_output_businesses(acc, bizz, options)
end

def cmd_business_find_businesses(acc, args, options)
  bid = []
  name = []
  fuzzy = []

  if args.any?
    flattened = args.map { |cell| cell.split(',') }.flatten
    if options.id
      bid += flattened
    elsif options.name
      name += flattened
    else
      fuzzy += flattened
    end
  end

  if any_business_pickers?(options)
    if options.business_id
      bid += [options.business_id]
    elsif options.business_name
      name += [options.business_name]
    elsif options.business
      fuzzy += [options.business]
    end
  end

  MrMurano::Verbose.whirly_start 'Looking for businesses...'
  bizz = acc.businesses(bid: bid, name: name, fuzzy: fuzzy)
  MrMurano::Verbose.whirly_stop

  bizz
end

def cmd_business_output_businesses(acc, bizz, options)
  if options.idonly
    headers = [:bizid]
    bizz = bizz.map(&:bizid)
  elsif options.brief
    #headers = %i[bizid role name]
    headers = %i[bizid name]
    bizz = bizz.map { |biz| [biz.bizid, biz.role, biz.name] }
  else
    # 2017-08-16: There are only 3 keys: bizid, role, and name.
    headers = bizz[0].meta.keys
    headers.sort_by! do |hdr|
      case hdr
      when :bizid
        0
      when :role
        1
      when :name
        2
      else
        3
      end
    end
    bizz = bizz.map { |biz| headers.map { |key| biz.meta[key] } }
  end

  io = File.open(options.output, 'w') if options.output
  acc.outf(bizz, io) do |dd, ios|
    if options.idonly
      ios.puts dd.join(' ')
    else
      acc.tabularize(
        {
          headers: headers.map(&:to_s),
          rows: dd,
        },
        ios,
      )
    end
  end
  io.close unless io.nil?
end

