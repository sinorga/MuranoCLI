require 'MrMurano/Account'
require 'MrMurano/SubCmdGroupContext'

command :solution do |c|
  c.syntax = %{murano solution}
  c.summary = %{About solution}
  c.description = %{Sub-commands for working with solution}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'solution create' do |c|
  c.syntax = %{murano solution create <name>}
  c.summary = %{Create a new solution}
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES, %{What type of solution to create. (default: product)}
  c.option '--save', %{Save new solution id to config}
  # FIXME/2017-06-01: Rebase conflict: [lb] thinks options.type is
  #   sufficient, and that we do not need options.section, since
  #   we can always deduce the type of solution.
  c.option '--section SECTION', String, %{Which section in config to save id to}

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
  c.description = %{Delete a solution}
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
alias_command 'product delete', 'solution delete'
alias_command 'app delete', 'solution delete'
alias_command 'application delete', 'solution delete'
alias_command 'solution rm', 'solution delete'

command 'solutions expunge' do |c|
  c.syntax = %{murano solution expunge}
  c.summary = %{Delete all solutions}
  c.description = %{Delete all solutions}
  c.action do |args, options|
    if args.count > 0 then
      acc.error "not expecting any arguments"
      return
    end
    name = '*'
    n_deleted, n_faulted = solution_delete(name, options)
    unless n_deleted.zero?
      # FIXME: Should this use "say" or "outf"?
      say "Deleted #{n_deleted} solutions"
    end
    unless n_faulted.zero?
      acc.error "Failed to delete #{n_faulted} solutions"
    end
  end
end
alias_command 'solutions delete', 'solutions expunge'
alias_command 'solutions rm', 'solutions expunge'

def solution_delete(name, options)
  acc = MrMurano::Account.new

  if name == '*'
    confirmed = MrMurano::Verbose::ask_yes_no("Really delete all solutions? [Y/n] ", true)
    unless confirmed
      acc.warning "abort!"
      return
    end
    name = ""
  end

  MrMurano::Verbose::whirly_start "Looking for solutions..."
  # Need to convert what we got into the internal PID.
  ret = acc.solutions(:all)
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
    unless name.empty? or ret.length == 1
      acc.warning "Unexpected number of solutions: found #{ret.length} but expected 1"
    end
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
  end

  return n_deleted, n_faulted
end

command 'solution list' do |c|
  c.syntax = %{murano solution list [options]}
  c.summary = %{List solution}
  c.description = %{List solution in the current business}
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES+[:all], %{What type of solutions to list. (default: all)}
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

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

#  vim: set ai et sw=2 ts=2 :
