require 'MrMurano/Account'
require 'MrMurano/SubCmdGroupContext'

command :solution do |c|
  c.syntax = %{murano solution}
  c.summary = %{About solution}
  c.description = %{
Sub-commands for working with solution.
  }.strip
  c.project_not_required = true

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'solution create' do |c|
  c.syntax = %{murano solution create <name>}
  c.summary = %{Create a new solution}
  c.description = %{
Create a new solution.
  }.strip
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES, %{What type of solution to create. (default: product)}
  c.option '--save', %{Save new solution id to config}
  # FIXME/2017-06-01: Rebase conflict: [lb] thinks options.type is
  #   sufficient, and that we do not need options.section, since
  #   we can always deduce the type of solution.
  c.option '--section SECTION', String, %{Which section in config to save id to}
  c.project_not_required = true

  c.action do |args, options|
    options.default :type => :product

    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Name of solution missing"
      return
    end
    name = args[0]

    ret = acc.new_solution(name, options.type)
    if ret.nil? then
      acc.error "Create failed"
      exit 5
    end
    if not ret.kind_of?(Hash) and not ret.empty? then
      acc.error "Create failed: #{ret.to_s}"
      return
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.solutions(options.type).select do |i|
      i[:name] == name or i[:domain] =~ /#{name}\./i
    end
    pid = (ret.first or {})[:apiId]
    if pid.nil? or pid.empty? then
      acc.error "Did not find an apiId!!!! #{name} -> #{ret} "
      exit 3
    end
    if options.save then
      section = options.type.to_s
      section = options.section.to_s unless options.section.nil?
      $cfg.set("#{section}.id", pid)
    end
    acc.outf pid

  end
end
alias_command 'product create', 'solution create' ,'--type', 'product'
alias_command 'app create', 'solution create', '--type', 'application'
alias_command 'application create', 'solution create','--type', 'application'

command 'solution delete' do |c|
  c.syntax = %{murano solution delete <id>}
  c.summary = %{Delete a solution}
  c.description = %{
Delete a solution.
  }.strip
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES+[:all], %{Only delete solution(s) of the specified type (default: all)}
  c.project_not_required = true

  c.action do |args, options|
    if args.count < 1 then
      acc.error "solution id or name missing"
      return
    end
    args.each do |name|
      solution_delete(name, options)
    end
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

command 'solutions expunge' do |c|
  c.syntax = %{murano solution expunge}
  c.summary = %{Delete all solutions}
  c.description = %{Delete all solutions}
  c.option '--yes', %{Answer "yes" to all prompts and run non-interactively.}
  c.project_not_required = true

  c.action do |args, options|
    if args.count > 0 then
      acc.error "not expecting any arguments"
      return
    end
    name = '*'
    n_deleted, n_faulted = solution_delete(name, options)
    unless n_deleted.nil? or n_deleted.zero?
      # FIXME: Should this use "say" or "outf"?
      inflection = MrMurano::Verbose::pluralize?("solution", n_deleted)
      say "Deleted #{n_deleted} #{inflection}"
    end
    unless n_faulted.nil? or n_faulted.zero?
      inflection = MrMurano::Verbose::pluralize?("solution", n_faulted)
      acc.error "Failed to delete #{n_faulted} #{inflection}"
    end
  end
end
alias_command 'solutions delete', 'solutions expunge'
alias_command 'solutions rm', 'solutions expunge'

def solution_delete(name, options)
  options.default :type=>:all

  acc = MrMurano::Account.new

  if name == '*'
    unless options.yes
      confirmed = MrMurano::Verbose::ask_yes_no("Really delete all solutions? [Y/n] ", true)
      unless confirmed
        acc.warning "abort!"
        return
      end
    end
    name = ""
  end

  MrMurano::Verbose::whirly_start "Looking for solutions..."
  # Need to convert what we got into the internal PID.
  ret = acc.solutions(options.type)
  unless name.empty?
    ret.select!{|i| i.has_value?(name) or i[:domain] =~ /#{name}\./i }
  end
  MrMurano::Verbose::whirly_stop

  if $cfg['tool.debug'] then
    say "Matches found:"
    acc.outf ret
  end

  n_deleted = 0
  n_faulted = 0
  if ret.empty? then
    unless name.empty?
      acc.error "No solution matching '#{name}' found. Nothing to delete."
    else
      acc.error "No solutions found. Nothing to delete."
    end
    exit 1
  else
    # Solutions of different types can have the same name, so warning that
    # more than one solution was found when searching by name is not valid.
    #unless name.empty? or ret.length == 1
    #  acc.warning "Unexpected number of solutions: found #{ret.length} for #{name} but expected 1"
    #end
    MrMurano::Verbose::whirly_start "Deleting solutions..."
    ret.each do |soln|
      delret = acc.delete_solution(soln[:sid])
      if not delret.kind_of?(Hash) and not delret.empty? then
        acc.error "Delete failed: #{delret.to_s}"
        n_faulted += 1
      else
        n_deleted += 1
        # Clear the ID from the config.
        MrMurano::Config::CFG_SOLUTION_ID_KEYS.each do |keyn|
          if $cfg[keyn] == soln[:sid]
            $cfg.set(keyn, nil)
          end
        end
      end
    end
    MrMurano::Verbose::whirly_stop
  end

  return n_deleted, n_faulted
end

command 'solution list' do |c|
  c.syntax = %{murano solution list [options]}
  c.summary = %{List solution}
  c.description = %{
List solution in the current business.
  }.strip
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES+[:all], %{What type of solutions to list (default: all)}
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}
  c.project_not_required = true

  c.action do |args, options|
    options.default :type=>:all, :all=>true
    acc = MrMurano::Account.new
    MrMurano::Verbose::whirly_start "Looking for solutions..."
    data = acc.solutions(options.type)
    MrMurano::Verbose::whirly_stop

    io = nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    if options.idonly then
      headers = [:apiId]
      data = data.map{|row| [row[:apiId]]}
    elsif not options.all then
      headers = [:apiId, :domain]
      data = data.map{|r| [r[:apiId], r[:domain]]}
    else
      headers = (data.first or {}).keys
      data = data.map{|r| headers.map{|h| r[h]}}
    end

    if !data.empty? or options.idonly
      acc.outf(data, io) do |dd, ios|
        if options.idonly then
          ios.puts dd.join(' ')
        else
          acc.tabularize({
            :headers=>headers.map{|h| h.to_s},
            :rows=>dd
          }, ios)
        end
      end
    else
      acc.warning "Did not find any solutions"
    end
    io.close unless io.nil?
  end
end
alias_command 'product list', 'solution list', '--type', 'product', '--no-all'
alias_command 'app list', 'solution list', '--type', 'application', '--no-all'
alias_command 'application list', 'solution list', '--type', 'application', '--no-all'
alias_command 'solutions list', 'solution list'

# To use fetch_solutions!, call command_add_solution_pickers(c) in
# the command block, and then call fetch_solutions! from the action.
def must_fetch_solutions(options)
  command_set_soln_picker_defaults(options)

  acc = MrMurano::Account.new

  MrMurano::Verbose::whirly_start "Fetching solutions..."
  resp = acc.solutions(options.type)
  MrMurano::Verbose::whirly_stop

  # Cull solutions if user specifies name(s) or ID(s).
  culled = select_solutions(resp, options)

  unless culled.length > 0
    acc.error "No solutions found."
    exit 0
  end

  solz = []

  culled.each do |desc|
    case desc[:type]
    when "product"
      soln = MrMurano::Product.new
    when "application"
      soln = MrMurano::Application.new
    else
      acc.warning "Unexpected solution type: #{desc[:type]}"
      soln = MrMurano::Solution.new(desc[:sid])
    end
    soln.desc = desc
    solz += [soln,]
  end

  solz
end

def command_add_solution_pickers(c)
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES, %{Find solution(s) by type}
  c.option '--ids IDS', Array, %{Find solution(s) by ID (IDS can be 1 ID or comma-separated list)}
  c.option '--names NAME', Array, %{Find solution(s) by name (NAMES can be 1 name or comma-separated list)}
  c.option '--find WORD', Array, %{Find solution(s) by word(s) (fuzzy match)}
  c.option '--[no-]header', %{Output solution descriptions}
end

def command_set_soln_picker_defaults(options)
  options.default :header=>true
  unless options.type
    options.type = :all
  end
  if options.ids.nil?
    options.ids = []
  end
  if options.names.nil?
    options.names = []
  end
  if options.find.nil?
    options.find = []
  end
  options
end

# 2017-06-15: [lb] not sure the best place for this function. So here for now.
def select_solutions(solz, options)
  if options.names.any? or options.ids.any? or options.find.any?
    solz = solz.select { |i|
      keep = false
      # Check exact name match of name or domain.
      if options.names.include? i[:name]
        keep = true
      end
      options.names.each do |name|
        if i[:domain] =~ /\b#{name}\./i
          keep = true
        end
      end
      # Check exact ID match.
      if options.ids.include? i[:sid]
        keep = true
      end
      # Check fuzzy name or domain match (or sid, for that matter).
      options.find.each do |name|
        if i[:sid] =~ /#{name}/i
          keep = true
        end
        if i[:name] =~ /#{name}/i
          keep = true
        end
        if i[:domain] =~ /#{name}/i
          keep = true
        end
      end

      # The type filter is applied in solutions() function,
      # but we should honor it here for completeness.
      if options.type and options.type != :all and i[:type] != options.type.to_s
        keep = false
      end

      # Keep the solution if at least one thing matched above.
      keep
    }
  end
  solz
end

#  vim: set ai et sw=2 ts=2 :

