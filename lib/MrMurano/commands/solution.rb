# Last Modified: 2017.08.16 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/ReCommander'
require 'MrMurano/SubCmdGroupContext'
require 'MrMurano/commands/business'
require 'MrMurano/commands/solution_picker'

command :solution do |c|
  c.syntax = %(murano solution)
  c.summary = %(About solution)
  c.description = %(
Commands for working with Application and Product solutions.
  ).strip
  c.project_not_required = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

# *** Create solution.
# --------------------

command 'solution create' do |c|
  c.syntax = %(murano solution create [--options] <solution-name>)
  c.summary = %(Create a new solution)
  c.description = %(
Create a new solution in the current business.
  ).strip
  c.project_not_required = true

  # Add flag: --type [application|product].
  cmd_add_solntype_pickers(c, exclude_all: true)

  c.option('--save', %(Save new solution ID to config))

  c.action do |args, options|
    c.verify_arg_count!(args, 1)
    cmd_defaults_solntype_pickers(options, :application)

    biz = MrMurano::Business.new
    biz.must_business_id!

    if args.count.zero?
      sol = biz.solution_from_type!(options.type)
      name = solution_ask_for_name(sol)
      names = [name]
    else
      names = args
    end

    # MAYBE: Support making multiple solutions.
    if names.length > 1
      MrMurano::Verbose.error('Can only make one solution at a time')
      exit 2
    end

    sol = biz.new_solution!(names.first, options.type)

    if options.save
      section = options.type.to_s
      $cfg.set("#{section}.id", sol.sid)
      $cfg.set("#{section}.name", sol.name)
    end

    biz.outf(sol.sid)
  end
end
alias_command 'create application', 'solution create', '--type', 'application'
alias_command 'create product', 'solution create', '--type', 'product'
alias_command 'application create', 'solution create', '--type', 'application'
alias_command 'product create', 'solution create', '--type', 'product'

# *** Delete solution(s).
# -----------------------

command 'solution delete' do |c|
  c.syntax = %(murano solution delete [--options] [<name-or-ID,...>])
  c.summary = %(Delete a solution)
  c.description = %(
Delete a solution from the business.
  ).strip
  c.project_not_required = true

  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  # Add --id and --name options.
  cmd_options_add_id_and_name(c)

  # Add soln pickers: --application* and --product*
  cmd_option_application_pickers(c)
  cmd_option_product_pickers(c)

  c.option('--recursive', %(If a solution is not specified, find all solutions and prompt before deleting.))
  # 2017-07-01: [lb] has /bin/rm aliased to /bin/rm -i so that I don't make
  # mistakes. So I added --prompt to behave similarly. Though maybe it should
  # be a config option? The alternative is --yes, though maybe there should
  # be a --no-yes?
  #c.option('--[no-]prompt', %(Prompt before removing))
  #c.option('--yes', %(Answer "yes" to all prompts and run non-interactively))
  c.option('--[no-]yes', %(Answer "yes" to all prompts and run non-interactively; if false, always prompt))

  c.action do |args, options|
    c.verify_arg_count!(args, nil, ['Missing name or ID'])
    cmd_defaults_solntype_pickers(options)
    cmd_defaults_id_and_name(options)

    biz = MrMurano::Business.new
    biz.must_business_id!

    nmorids = cmd_solution_del_get_names_and_ids!(biz, args, options)

    n_deleted = 0
    n_faulted = 0

    nmorids.each do |name_or_id|
      unless options.yes
        confirmed = MrMurano::Verbose.ask_yes_no(
          "Really delete #{name_or_id[0]}? [y/N] ", false
        )
        unless confirmed
          MrMurano::Verbose.warning("Skipping #{name_or_id[0]}!")
          next
        end
      end
      m_deleted, m_faulted = solution_delete(
        name_or_id[0], use_sol: name_or_id[2], type: options.type, yes: options.yes
      )
      n_deleted += m_deleted
      n_faulted += m_faulted
    end
    # Print results if something happened and was recursive (otherwise
    # behave like, say, /bin/rm, and just be silent on success).
    solution_delete_report(n_deleted, n_faulted) if options.recursive
  end
end
alias_command 'delete application', 'solution delete', '--type', 'application'
alias_command 'delete product', 'solution delete', '--type', 'product'
alias_command 'application delete', 'solution delete', '--type', 'application'
alias_command 'product delete', 'solution delete', '--type', 'product'

def cmd_solution_del_get_names_and_ids!(biz, args, options)
  nmorids = []
  if args.count.zero?
    if any_solution_pickers!(options)
      exit_cmd_not_recursive!
    elsif !options.recursive
      MrMurano::Verbose.error(
        'Please specify the name or ID of the solution to delete, or use --recursive.'
      )
      exit 1
    end
  else
    exit_cmd_not_recursive!
  end
  solz = must_fetch_solutions!(options, args, biz)
  solz.each do |sol|
    nmorids += [[sol.sid, "‘#{sol.name}’ <#{sol.sid}>", sol]]
  end
  nmorids
end

def exit_cmd_not_recursive!
  MrMurano::Verbose.error(
    'The --recursive option does not apply when specifing solution IDs or names.'
  )
  exit 1
end

# The `murano solutions expunge -y` command simplifies what be done
# craftily other ways, e.g.,:
#
#   $ for pid in $(murano product list --idonly) ; do murano product delete $pid ; done
command 'solutions expunge' do |c|
  c.syntax = %(murano solution expunge)
  c.summary = %(Delete all solutions)
  c.description = %(
Delete all solutions in business.
  ).strip
  c.option('-y', '--yes', %(Answer "yes" to all prompts and run non-interactively))
  c.project_not_required = true

  c.action do |args, options|
    c.verify_arg_count!(args)
    name_or_id = '*'
    n_deleted, n_faulted = solution_delete(name_or_id, yes: options.yes)
    solution_delete_report(n_deleted, n_faulted)
  end
end

def solution_delete(name_or_id, use_sol: nil, type: :all, yes: false)
  biz = MrMurano::Business.new
  biz.must_business_id!

  if name_or_id == '*'
    unless yes
      confirmed = MrMurano::Verbose.ask_yes_no('Really delete all solutions? [y/N] ', false)
      unless confirmed
        MrMurano::Verbose.warning('abort!')
        return
      end
    end
    name_or_id = ''
  end

  if !use_sol.nil?
    solz = [use_sol]
  else
    MrMurano::Verbose.whirly_start('Looking for solutions...')
    solz = biz.solutions(type: type)
    # This used to use Hash.value? to see if the name exactly matches
    # any key's value. But we should be able to stick to using name.
    #  (E.g., it used to call sol.meta.value?(name_or_id), but this
    #   would return true if, say, sol.meta[:any_key] equaled name_or_id.)
    unless name_or_id.empty?
      solz.select! do |sol|
        sol.sid == name_or_id || sol.name == name_or_id || sol.domain =~ /#{Regexp.escape(name_or_id)}\./i
      end
    end
    MrMurano::Verbose.whirly_stop
    if $cfg['tool.debug']
      say 'Matches found:'
      biz.outf(solz)
    end
  end

  n_deleted = 0
  n_faulted = 0
  if solz.empty?
    if !name_or_id.empty?
      MrMurano::Verbose.error("No solution matching ‘#{name_or_id}’ found")
    else
      MrMurano::Verbose.error(MSG_SOLUTIONS_NONE_FOUND)
    end
    exit 1
  else
    # Solutions of different types can have the same name, so warning that
    # more than one solution was found when searching by name is not valid.
    #unless name_or_id.empty? or solz.length == 1
    #  MrMurano::Verbose.warning(
    #    "Unexpected number of solutions: found #{solz.length} for #{name_or_id} but expected 1"
    #  )
    #end
    MrMurano::Verbose.whirly_start('Deleting solutions...')
    solz.each do |sol|
      ret = biz.delete_solution(sol.sid)
      if !ret.is_a?(Hash) && !ret.empty?
        MrMurano::Verbose.error("Delete failed: #{ret}")
        n_faulted += 1
      else
        n_deleted += 1
        # Clear the ID from the config.
        MrMurano::Config::CFG_SOLUTION_ID_KEYS.each do |keyn|
          $cfg.set(keyn, nil) if $cfg[keyn] == sol.sid
        end
      end
    end
    MrMurano::Verbose.whirly_stop
  end

  [n_deleted, n_faulted]
end

def solution_delete_report(n_deleted, n_faulted)
  unless n_deleted.nil? || n_deleted.zero?
    # FIXME: Should this use 'say' or 'outf'?
    inflection = MrMurano::Verbose.pluralize?('solution', n_deleted)
    say "Deleted #{n_deleted} #{inflection}"
  end
  return if n_faulted.nil? || n_faulted.zero?
  inflection = MrMurano::Verbose.pluralize?('solution', n_faulted)
  MrMurano::Verbose.error("Failed to delete #{n_faulted} #{inflection}")
end

# *** List and Find solutions.
# ----------------------------

def cmd_solution_find_add_options(c)
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]brief', 'Show fewer fields: only Solution ID and domain'
  c.option '--[no-]all', 'Find all Solutions in Business, not just Project'
  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)
end

command 'solution list' do |c|
  c.syntax = %(murano solution list [--options])
  c.summary = %(List solutions)
  c.description = %(
List solutions in the current business.
  ).strip
  c.project_not_required = true

  cmd_solution_find_add_options(c)

  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.action do |args, options|
    c.verify_arg_count!(args)
    cmd_defaults_solntype_pickers(options)
    cmd_solution_find_and_output(args, options)
  end
end
alias_command 'list application', 'solution list', '--type', 'application', '--brief'
alias_command 'list product', 'solution list', '--type', 'product', '--brief'
alias_command 'application list', 'solution list', '--type', 'application', '--brief'
alias_command 'product list', 'solution list', '--type', 'product', '--brief'
#
alias_command 'list solutions', 'solution list'
alias_command 'list applications', 'application list'
alias_command 'list products', 'product list'
alias_command 'solutions list', 'solution list'
alias_command 'applications list', 'application list'
alias_command 'products list', 'product list'

command 'solution find' do |c|
  c.syntax = %(murano solution find [--options] [<name-or-ID,...>])
  c.summary = %(Find solution by name or ID)
  c.description = %(
Find solution by name or ID.
  ).strip
  c.project_not_required = true

  cmd_solution_find_add_options(c)

  cmd_add_solntype_pickers(c)

  # Add --id and --name options.
  cmd_options_add_id_and_name(c)

  # Add soln pickers: --application* and --product*
  cmd_option_application_pickers(c)
  cmd_option_product_pickers(c)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    cmd_defaults_solntype_pickers(options)
    cmd_defaults_id_and_name(options)
    if args.none? && !any_solution_pickers!(options)
      MrMurano::Verbose.error('What would you like to find?')
      exit 1
    end
    cmd_solution_find_and_output(args, options)
  end
end
alias_command 'find application', 'solution find', '--type', 'application', '--brief'
alias_command 'find product', 'solution find', '--type', 'product', '--brief'
alias_command 'application find', 'solution find', '--type', 'application', '--brief'
alias_command 'product find', 'solution find', '--type', 'product', '--brief'

def cmd_solution_find_and_output(args, options)
  cmd_verify_args_and_id_or_name!(args, options)
  biz = MrMurano::Business.new
  biz.must_business_id!
  solz = cmd_solution_find_solutions(biz, args, options)
  if solz.empty? && !options.idonly
    MrMurano::Verbose.error(MSG_SOLUTIONS_NONE_FOUND)
    exit 0
  end
  cmd_solution_output_solutions(biz, solz, options)
end

def cmd_solution_find_solutions(biz, args, options)
  must_fetch_solutions!(options, args, biz)
end

def cmd_solution_output_solutions(biz, solz, options)
  if options.idonly
    headers = %i[apiId]
    solz = solz.map { |row| [row.apiId] }
  elsif options.brief
    #headers = %i[apiId domain]
    #solz = solz.map { |row| [row.apiId, row.domain] }
    headers = %i[apiId domain name]
    solz = solz.map { |row| [row.apiId, row.domain, row.name] }
  else
    headers = (solz.first && solz.first.meta || {}).keys
    headers.delete(:sid) if headers.include?(:apiId) && headers.include?(:sid)
    headers.sort_by! do |hdr|
      case hdr
      when :bizid
        0
      when :type
        1
      when :apiId
        2
      when :domain
        3
      when :name
        4
      else
        5
      end
    end
    solz = solz.map { |row| headers.map { |hdr| row.meta[hdr] } }
  end

  io = File.open(options.output, 'w') if options.output
  biz.outf(solz, io) do |dd, ios|
    if options.idonly
      ios.puts(dd.join(' '))
    else
      biz.tabularize(
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

