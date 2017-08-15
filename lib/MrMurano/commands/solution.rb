# Last Modified: 2017.08.14 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/SubCmdGroupContext'
require 'MrMurano/commands/solution-picker'

command :solution do |c|
  c.syntax = %(murano solution)
  c.summary = %(About solution)
  c.description = %(
Commands for working with solutions, including Applications and Products.
  ).strip
  c.project_not_required = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'solution create' do |c|
  c.syntax = %(murano solution create <name>)
  c.summary = %(Create a new solution)
  c.description = %(
Create a new solution.
  ).strip
  c.option(
    '--type TYPE',
    MrMurano::Business::ALLOWED_TYPES,
    %(What type of solution to create (default: product))
  )
  c.option('--save', %(Save new solution id to config))
  # FIXME/2017-06-01: Rebase conflict introduced --section:
  #   [lb] thinks options.type is sufficient,
  #   and that we do not need options.section,
  #   since we can always deduce the type of solution.
  #c.option('--section SECTION', String, %(Which section in config to save id to))
  c.project_not_required = true

  c.action do |args, options|
    options.default(type: :product)

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
      #section = options.section.to_s unless options.section.nil?
      $cfg.set("#{section}.id", sol.sid)
      $cfg.set("#{section}.name", sol.name)
    end

    biz.outf(sol.sid)
  end
end
alias_command 'product create', 'solution create', '--type', 'product'
alias_command 'app create', 'solution create', '--type', 'application'
alias_command 'application create', 'solution create', '--type', 'application'

command 'solution delete' do |c|
  c.syntax = %(murano solution delete <NAME_OR_ID>)
  c.summary = %(Delete a solution)
  c.description = %(
Delete a solution.
  ).strip
  c.option(
    '--type TYPE',
    MrMurano::Business::ALLOWED_TYPES + [:all],
    %(Only delete solution(s) of the specified type (default: all))
  )
  c.option('--recursive', %(If a solution is not specified, find all solutions and prompt before deleting.))
  # 2017-07-01: [lb] has /bin/rm aliased to /bin/rm -i so that I don't make
  # mistakes. So I added --prompt to behave similarly. Though maybe it should
  # be a config option? The alternative is --yes, though maybe there should
  # be a --no-yes?
  #c.option('--[no-]prompt', %(Prompt before removing))
  #c.option('--yes', %(Answer "yes" to all prompts and run non-interactively))
  c.option('--[no-]yes', %(Answer "yes" to all prompts and run non-interactively; if false, always prompt))
  c.project_not_required = true

  c.action do |args, options|
    options.default(type: :all, recursive: false, prompt: nil)

    biz = MrMurano::Business.new
    biz.must_business_id!

    nmorids = []
    #do_confirm = options.prompt unless options.prompt.nil?
    do_confirm = !options.yes unless options.yes.nil?
    if args.count.zero?
      if options.recursive
        #do_confirm = true if do_confirm.nil? && !options.yes
        do_confirm = true if do_confirm.nil?
        solz = solution_get_solutions(biz, options.type)
        if solz.empty?
          MrMurano::Verbose.warning(MSG_SOLUTIONS_NONE_FOUND)
          exit 1
        else
          solz.each do |sol|
            nmorids += [[sol.sid, "‘#{sol.name}’ <#{sol.sid}>", sol]]
          end
        end
      else
        MrMurano::Verbose.error(
          'Please specify the name or ID of the solution to delete, or use --recursive.'
        )
        exit 1
      end
    else
      args.each do |arg|
        nmorids += [[arg, "‘#{arg}’", nil]]
      end
    end

    n_deleted = 0
    n_faulted = 0

    nmorids.each do |name_or_id|
      if do_confirm
        confirmed = MrMurano::Verbose.ask_yes_no(
          "Really delete #{name_or_id[0]}? [Y/n] ", true
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
alias_command 'product delete', 'solution delete', '--type', 'product'
alias_command 'app delete', 'solution delete', '--type', 'application'
alias_command 'application delete', 'solution delete', '--type', 'application'
# 2017-06-19: [lb] wondering if 'rm' aliases would be useful...
alias_command 'solution rm', 'solution delete'
alias_command 'product rm', 'solution delete', '--type', 'product'
alias_command 'app rm', 'solution delete', '--type', 'application'
alias_command 'application rm', 'solution delete', '--type', 'application'

# The `murano solutions expunge -y` command simplifies what be done
# craftily other ways, e.g.,:
#
#   $ for pid in $(murano product list --idonly) ; do murano product delete $pid ; done
command 'solutions expunge' do |c|
  c.syntax = %(murano solution expunge)
  c.summary = %(Delete all solutions)
  c.description = %(
Delete all solutions.
  ).strip
  c.option('--yes', %(Answer "yes" to all prompts and run non-interactively))
  c.project_not_required = true

  c.action do |args, options|
    c.verify_arg_count!(args)
    name_or_id = '*'
    n_deleted, n_faulted = solution_delete(name_or_id, yes: options.yes)
    solution_delete_report(n_deleted, n_faulted)
  end
end
alias_command 'solutions delete', 'solutions expunge'
alias_command 'solutions rm', 'solutions expunge'

def solution_delete(name_or_id, use_sol: nil, type: :all, yes: false)
  biz = MrMurano::Business.new
  biz.must_business_id!

  if name_or_id == '*'
    unless yes
      confirmed = MrMurano::Verbose.ask_yes_no('Really delete all solutions? [Y/n] ', true)
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
    solz = biz.solutions(type)
    # This used to use Hash.value? to see if the name exactly matches
    # any key's value. But we should be able to stick to using name.
    #  (E.g., it used to call sol.meta.value?(name_or_id), but this
    #   would return true if, say, sol.meta[:any_key] equaled name_or_id.)
    unless name_or_id.empty?
      solz.select! do |sol|
        sol.sid == name_or_id || sol.name == name_or_id || sol.domain =~ /#{name_or_id}\./i
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

command 'solution list' do |c|
  c.syntax = %(murano solution list [options])
  c.summary = %(List solution)
  c.description = %(
List solution in the current business.
  ).strip
  c.option(
    '--type TYPE',
    MrMurano::Business::ALLOWED_TYPES + [:all],
    %(What type of solutions to list (default: all)),
  )
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)
  c.project_not_required = true

  c.action do |_args, options|
    options.default(type: :all, all: true)

    biz = MrMurano::Business.new
    biz.must_business_id!

    MrMurano::Verbose.whirly_start('Looking for solutions...')
    solz = biz.solutions(options.type)
    MrMurano::Verbose.whirly_stop

    io = File.open(options.output, 'w') if options.output

    if options.idonly
      headers = %i[apiId]
      solz = solz.map { |row| [row.apiId] }
    elsif !options.all
      headers = %i[apiId domain]
      solz = solz.map { |row| [row.apiId, row.domain] }
    else
      headers = (solz.first && solz.first.meta || {}).keys
      headers.delete(:sid) if headers.include?(:apiId) && headers.include?(:sid)
      solz = solz.map { |row| headers.map { |hdr| row.meta[hdr] } }
    end

    if !solz.empty? || options.idonly
      biz.outf(solz, io) do |dd, ios|
        if options.idonly
          ios.puts(dd.join(' '))
        else
          biz.tabularize(
            {
              # Use Symbol.to_proc trickery. & calls to_proc on the object.
              #  http://www.brianstorti.com/understanding-ruby-idiom-map-with-symbol/
              #headers: headers.map { |h| h.to_s },
              headers: headers.map(&:to_s),
              rows: dd,
            },
            ios,
          )
        end
      end
    else
      MrMurano::Verbose.warning('Did not find any solutions')
    end
    # "The Safe Navigation Operator (&.) in Ruby"
    #  http://mitrev.net/ruby/2015/11/13/the-operator-in-ruby/
    # The safe nav op was only added in Ruby 2.3.0, and we support 2.0.
    #io&.close
    io.close unless io.nil?
  end
end
alias_command 'product list', 'solution list', '--type', 'product', '--no-all'
alias_command 'app list', 'solution list', '--type', 'application', '--no-all'
alias_command 'application list', 'solution list', '--type', 'application', '--no-all'
alias_command 'solutions list', 'solution list'

