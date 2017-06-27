
command :config do |c|
  c.syntax = %{murano config [options] <key> [<new value>]}
  c.summary = %{Get and set options}
  c.description = %{
Get, set, or query config options.

All config options are in a 'section.key' format.

There is also a layer of scopes that the keys can be saved in.

If section is left out, then key is assumed to be in the 'tool' section.
  }.strip

  c.example %{
    View the combined config
  }.strip, 'murano config --dump'

  c.example %{
    View the config and path for each config file
  }.strip, 'murano config --locations'

  c.example %{
    Query a value
  }.strip, 'murano config solution.id'

  c.example %{
    Set a new value, which writes to the project config file
  }.strip, 'murano config solution.id XXXXXXXX'

  c.example %{
    Set a new valuem, and write it to the user config file
  }.strip, 'murano config --user user.name my@email.address'

  c.example %{
    Unset a value. If the value is set in multiple config files,
    # this unsets it from the outermost config file and unmasks
    # a value set in a lower scope
  }.strip, 'murano config diff.cmd --unset'

  c.option '--user', 'Use only the config file in $HOME (.mrmuranorc)'
  c.option '--project', 'Use only the config file in the project (.mrmuranorc)'
  c.option '--env', 'Use only the config file from $MR_CONFIGFILE'
  c.option '--specified', 'Use only the config file from the --config option.'

  c.option '--unset', 'Remove key from config file.'
  c.option '--dump', 'Dump the current combined view of the config'
  c.option '--locations', 'List the locations of all known configs'

  c.project_not_required = true

  c.action do |args, options|

    if options.dump then
      puts $cfg.dump()
    elsif options.locations then
      puts "This list is ordered. The first value found for a key is the value used."
      puts $cfg.locations()
    elsif args.count == 0 then
      say_error "Need a config key"
    elsif args.count == 1 and not options.unset then
      options.default :user=>false, :project=>false,
        :specified=>false, :env=>false

      # For read, if no scopes, than all. Otherwise just those specified
      scopes = []
      scopes << :user if options.user
      scopes << :project if options.project
      scopes << :env if options.env
      scopes << :specified if options.specified
      scopes = MrMurano::Config::CFG_SCOPES if scopes.empty?

      say $cfg.get(args[0], scopes)
    else

      options.default :user=>false, :project=>false,
        :specified=>false, :env=>false
      # For write, if scope is specified, only write to that scope.
      scope = :project
      scope = :user if options.user
      scope = :project if options.project
      scope = :env if options.env
      scope = :specified if options.specified

      args[1] = nil if options.unset
      $cfg.set(args[0], args[1], scope)
    end
  end

end

#  vim: set ai et sw=2 ts=2 :

