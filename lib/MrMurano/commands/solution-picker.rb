# Last Modified: 2017.08.14 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

MSG_SOLUTIONS_NONE_FOUND = 'No solutions found'

def command_add_biz_and_solz_pickers(c)
  command_add_business_pickers(c)
  command_add_solution_pickers(c)
  command_add_application_pickers(c)
  command_add_product_pickers(c)
end

def command_add_biz_and_application_pickers(c)
  command_add_business_pickers(c)
  command_add_solution_pickers(c)
  command_add_application_pickers(c)
end

def command_add_biz_and_product_pickers(c)
  command_add_business_pickers(c)
  command_add_solution_pickers(c)
  command_add_product_pickers(c)
end

def command_add_solution_pickers(c)
  types = MrMurano::Business::ALLOWED_TYPES.join(', ')
  # 2017-07-26: HA! The --type option can get masked by aliases.
  # For instance, if the option is required ("--type TYPE"), then
  #   murano domain --type product
  # fails, because the "domain product" alias steals the --type argument,
  # so the parser exits, complaining that --type is missing an argument!
  # This, however, works:
  #   murano domain --type=product
  # as does
  #   murano domain -t product
  # To work around this, make the argument optional ("--type [TYPE]") and
  # then do some extra processing later to check for this special case.
  c.option(
    '--type [TYPE]',
    MrMurano::Business::ALLOWED_TYPES,
    %(Find solution(s) by type (one of: #{types}))
  )
  c.option(
    '--id ID[,ID,...]',
    Array,
    %(Find solution(s) by ID (specify one or more comma-separated IDs))
  )
  c.option(
    '--name NAME[,NAME,...]',
    Array,
    %(Find solution(s) by name (specify one or more comma-separated NAMES))
  )
  c.option(
    '--find WORD', Array, %(Find solution(s) by word(s) (fuzzy match))
  )
  c.option(
    '--[no-]header', %(Output solution descriptions)
  )
end

def command_add_application_pickers(c)
  c.option('--application[=APPLICATION]', String, %(Name or ID of Application to use)) do |application_mark|
    # NOTE: If user does not specify an argument,
    #         e.g., `murano domain --application`,
    #       then this block *is not* called.
    $cfg['application.id'] = nil
    $cfg['application.name'] = nil
    $cfg['application.mark'] = application_mark
  end
  c.option('--application-name NAME', String, %(Name of Application to use)) do |application_name|
    $cfg['application.id'] = nil
    $cfg['application.name'] = application_name
    $cfg['application.mark'] = nil
  end
  c.option('--application-id ID', String, %(ID of Application to use)) do |application_id|
    $cfg['application.id'] = application_id
    $cfg['application.name'] = nil
    $cfg['application.mark'] = nil
  end
end

def command_add_product_pickers(c)
  c.option('--product[=PRODUCT]', String, %(Name or ID of Product to use)) do |product_mark|
    $cfg['product.id'] = nil
    $cfg['product.name'] = nil
    $cfg['product.mark'] = product_mark
  end
  c.option('--product-name NAME', String, %(Name of Product to use)) do |product_name|
    $cfg['product.id'] = nil
    $cfg['product.name'] = product_name
    $cfg['product.mark'] = nil
  end
  c.option('--product-id ID', String, %(ID of Product to use)) do |product_id|
    $cfg['product.id'] = product_id
    $cfg['product.name'] = nil
    $cfg['product.mark'] = nil
  end
end

# To use must_fetch_solutions!, call command_add_solution_pickers(c) in
# the command block, and then call fetch_solutions! from the action.
def must_fetch_solutions!(options)
  command_defaults_solution_picker(options)

  biz = MrMurano::Business.new
  biz.must_business_id!

  MrMurano::Verbose.whirly_start('Fetching solutions...')
  solz = biz.solutions(options.type)
  MrMurano::Verbose.whirly_stop

  # Cull solutions if user specifies name(s) or ID(s).
  culled = select_solutions(solz, options)

  if culled.empty?
    MrMurano::Verbose.error(MSG_SOLUTIONS_NONE_FOUND)
    exit 0
  end

  culled
end

def command_defaults_solution_picker(options)
  options.default(header: true)
  if options.type == true
    # KLUDGE/2017-07-26: Work around rb-commander peculiarity.
    # The alias_command stole the --type parameter, e.g.,
    #   murano domain --type product
    # is interpreted using the "domain product" alias,
    # so the command that's parsed is actually
    #   murano domain --type product --type
    # and the latter --type wins [which is something that [lb]
    # really dislikes about rb-commander, is that it does not
    # support more than one of the same options, taking only the
    # last one's argument].
    next_posit = 1
    ARGV.each do |arg|
      if arg.casecmp('--type').zero?
        if ARGV.length == next_posit
          MrMurano::Verbose.error('missing argument: --type')
          exit 1
        else
          # NOTE: Commander treats arguments case sensitively, but not --options.
          possible_type = ARGV[next_posit].to_sym
          if MrMurano::Business::ALLOWED_TYPES.include?(possible_type)
            options.type = possible_type
          else
            MrMurano::Verbose.error("unrecognized --type: #{possible_type}")
            exit 1
          end
          break
        end
      end
      next_posit += 1
    end
    if options.type == true
      MrMurano::Verbose.error('missing argument: --type')
      exit 1
    end
  else
    # --application and --product are abused options: when specified without
    # an argument, they're aliases for --type application and --type product,
    # respectively; but when specified with an argument, the argument is the
    # name or ID of a solution.
    num_ways = 0
    num_ways += 1 if options.application == true
    num_ways += 1 if options.product == true
    num_ways += 1 if options.type
    if num_ways.zero?
      options.type = :all
    elsif num_ways == 1
      if options.application == true
        options.type = :application
        options.application = nil
      elsif options.product == true
        options.type = :product
        options.product = nil
      # else, options.type already set.
      end
    else
      MrMurano::Verbose.error(
        'ambiguous intention: please specify only one of --type, --application, or --product'
      )
      exit 1
    end
  end
  options.ids = [] if options.ids.nil?
  options.names = [] if options.names.nil?
  options.find = [] if options.find.nil?
  options
end

# select_solutions filters the list of solutions in sol
def select_solutions(solz, options)
  if options.names.any? ||
      options.ids.any? ||
      options.find.any? ||
      options.application_id
    solz = solz.select do |sol|
      keep = false
      # Check exact name match of name or domain.
      keep = true if options.names.include?(sol.name)
      options.names.each do |name|
        keep = true if sol.domain =~ /\b#{name}\./i
      end
      # Check exact ID match.
      keep = true if options.ids.include?(sol.sid)
      # Check fuzzy name or domain match (or sid, for that matter).
      options.find.each do |name|
        keep = true if sol.sid =~ /#{name}/i
        keep = true if sol.name =~ /#{name}/i
        keep = true if sol.domain =~ /#{name}/i
      end
      # The type filter is applied in solutions() function,
      # but we should honor it here for completeness.
      keep = false if options.type && options.type != :all && sol.type != options.type.to_s
      # Keep the solution if at least one thing matched above.
      keep
    end
  end
  solz
end

def solution_get_solutions(biz, type, match_sid=nil, match_name=nil, match_either=nil)
  if type == :all
    inflection = 'solutions'
  else
    inflection = MrMurano::Verbose.pluralize?(type.to_s, 0)
  end
  MrMurano::Verbose.whirly_start("Fetching #{inflection}...")
  invalidate = false
  solz = biz.solutions(type, invalidate, match_sid, match_name, match_either)
  MrMurano::Verbose.whirly_stop
  solz
end

def solution_ask_for_name(sol)
  asking = true
  while asking
    solname = ask("Please enter the #{sol.type_name} name: ")
    puts ''
    if solname == ''
      confirmed = ask("\nReally skip the #{sol.type_name}? [Y/n] ", true)
      if confirmed
        puts ''
        return '', '', false
      end
    else
      #unless sol.name.match(sol.name_validate_regex) { say ... }
      begin
        sol.set_name!(solname)
        break
      rescue MrMurano::ConfigError => _err
        say(sol.name_validate_help)
        # keep looping
      end
    end
  end
  sol.name
end

# *** Code for interacting with user to identify the solution.

# For more on the ** doublesplat, and the **_ starsnake, see:
#  https://flushentitypacket.github.io/ruby/2015/03/31/ruby-keyword-arguments-the-double-splat-and-starsnake.html
# "Basically, _ is Ruby’s variable name for storing values you don’t need."
# Ruby 2.0 and above. I don't think we support 1.x...

def get_product_and_application!(**options)
  biz = MrMurano::Business.new
  appl = solution_find_or_create(biz: biz, type: :application, **options)
  prod = solution_find_or_create(biz: biz, type: :product, **options)
  [appl, prod]
end

def solution_find_or_create(biz: nil, type: nil, **options)
  options[:match_enable] = true if options[:match_enable].nil?
  # Add any search terms the user specified, e.g., --application XXX.
  options[:match_sid] = $cfg.get("#{type}.id", :internal)
  options[:match_name] = $cfg.get("#{type}.name", :internal)
  options[:match_either] = $cfg.get("#{type}.mark", :internal)
  finder = MrMurano::InteractiveSolutionFinder.new(options)
  model = biz.solution_from_type!(type)
  finder.find_or_create(model)
end

module MrMurano
  # A class for finding solutions, either automatically or interactively.
  class InteractiveSolutionFinder
    def initialize(
      skip_verify: false,
      create_ok: false,
      update_cfg: false,
      ignore_cfg: false,
      verbose: false,
      match_enable: false,
      match_sid: nil,
      match_name: nil,
      match_either: nil
    )
      @skip_verify = skip_verify
      @create_ok = create_ok
      @update_cfg = update_cfg
      @ignore_cfg = ignore_cfg
      @verbose = verbose
      @match_enable = match_enable
      @match_sid = match_sid
      @match_name = match_name
      @match_either = match_either
      @match_sid = nil if @match_sid.to_s.empty?
      @match_name = nil if @match_name.to_s.empty?
      @match_either = nil if @match_either.to_s.empty?
      @searching = @match_enable && (@match_sid || @match_name || @match_either)
    end

    def find_or_create(model)
      # First, try to find the solution by solution ID.
      sol = solution_find_by_sid(model)
      # If not found, search existing solutions, and maybe ask user.
      if sol.nil?
        if @searching
          sol = solution_search_by_term(model)
          sol = solution_create_new_solution(model) if sol.nil? && @create_ok && @match_sid.nil?
        end
        sol = solution_lookup_or_ask(model) unless @searching
      end
      # Finally, if asked, update the config.
      if @update_cfg && !sol.nil?
        # Update the config in memory and on disk/file.
        $cfg.set(sol.cfg_key_id, sol.sid, :project)
        $cfg.set(sol.cfg_key_name, sol.name, :project)
      end
      sol
    end

    def solution_find_by_sid(sol)
      exists = false
      if @searching || @ignore_cfg
        sol.sid = @match_sid || @match_either
      else
        # Note that we verify the solution ID we find in the config,
        # since the user could've, e.g., deleted it via the web UI.
        # LATER: This only works so long as there's only one Product
        #  or one Application. Eventually we'll add support for more.
        sol.sid = $cfg[sol.cfg_key_id].to_s
        return sol if @skip_verify
      end
      if sol.sid?
        if @searching
          whirly_msg = "Searching #{sol.type_name} by ID..."
        else
          whirly_msg = "Verifying #{sol.type_name}..."
        end
        MrMurano::Verbose.whirly_start(whirly_msg)
        sol.info_safe
        if sol.valid_sid
          exists = true
        else
          sol.sid = nil
        end
        MrMurano::Verbose.whirly_stop
        # Spit out some messages, maybe.
        if @verbose
          if exists
            say "Found #{sol.type_name} #{sol.pretty_desc}"
          elsif !@searching
            # The solution ID in the config was not found for this business.
            say "The #{sol.type_name} ‘#{sol.sid}’ found in the config does not exist"
          end
          puts ''
        end
      end
      (exists && sol) || nil
    end

    def solution_lookup_or_ask(sol)
      solz = solution_get_solutions(sol.biz, sol.type)
      if solz.count == 1
        sol = solz.first
        #say "This business has one #{sol.type_name}. Using #{Rainbow(sol.domain).underline}"
        say "This business has one #{sol.type_name}. Using #{sol.pretty_desc}" if @verbose
        puts '' if @verbose
      elsif solz.count.zero?
        if @create_ok
          sol = solution_create_new_solution(sol)
        else
          sol.error("No #{Inflecto.pluralize(sol.type.to_s)} found")
          sol = nil
        end
      else
        solution_choose_solution(solz, sol.type_name)
      end
      sol
    end

    def solution_create_new_solution(sol)
      # See if user specified name using a switch option.
      solname = nil
      solname = @match_name if solname.nil?
      solname = @match_either if solname.nil?
      if solname.nil?
        #say "You do not have any #{type}s. Let's create one."
        if @verbose
          say("This business does not have any #{Inflecto.pluralize(sol.type.to_s)}. Let's create one")
          puts ''
        end
        solution_ask_for_name(sol)
      else
        sol.set_name!(solname)
      end
      # MAYBE/2017-07-20: Detect if Business is ADC enabled. If not,
      # creating a solution fails, e.g.,
      #   Request Failed: 409: [409] upgrade
      sol = sol.biz.new_solution!(sol.name, sol.type) unless sol.name.to_s.empty?
      say "Created new #{sol.pretty_desc(add_type: true)}" if @verbose
      puts '' if @verbose
      sol
    end

    def solution_choose_solution(solz, type_name)
      sol = nil
      choose do |menu|
        menu.prompt = "Select which #{type_name} to use:"
        menu.flow = :columns_across
        # NOTE: There are 2 human friendly identifiers, :name and :domain.
        solz.sort_by(&:domain).each do |option|
          menu.choice(option.domain.sub(/\..*$/, '')) do
            sol = option
          end
        end
      end
      sol
    end

    def solution_search_by_term(sol)
      solz = solution_get_solutions(
        sol.biz, sol.type, @match_sid, @match_name, @match_either
      )
      if solz.length > 1
        sol.error("More than one matching #{sol.type_name} found. Please be more specific")
        sol = nil
        # MAYBE/2017-07-01: Show interactive menu.
        # For now, if we didn't exit, weird behavior might occur, e.g., if
        # user calls `murano init --application foo` and 2 matches are found,
        # if we returned nil, the code would create a new application.
        exit 1
      elsif solz.length.zero?
        inflection = MrMurano::Verbose.pluralize?(sol.type_name, 0)
        # Only blather an error if we're not about to create a new solution.
        sol.error("No matching #{inflection} found.") unless @create_ok
        sol = nil
        # It's okay not to exit. If `murano init` was called, a new
        # solution will be created; otherwise, the command will exit.
      else
        sol = solz.first
        say "Found one matching #{sol.type_name}. Using #{sol.pretty_desc}" if @verbose
        puts '' if @verbose
      end
      sol
    end
  end
end

