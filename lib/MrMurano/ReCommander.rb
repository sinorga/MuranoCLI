require 'MrMurano/verbosing'

module MrMurano
  class Hooked
    include Verbose
    attr :section

    def initialize(section)
      @section = section
    end

    def check_run_pre_hook
      prehook = $cfg["#{section}.pre-hook"]
      return if prehook.nil?
      return if prehook.empty?
      verbose "calling pre-hook: #{prehook}"
      system(prehook)
    end

    def check_run_post_hook
      posthook = $cfg["#{section}.post-hook"]
      return if posthook.nil?
      return if posthook.empty?
      verbose "calling post-hook: #{posthook}"
      system(posthook)
    end

  end
end

module Commander
  class Command
    attr_accessor :project_not_required
  end

  class Runner
    attr_accessor :command_exit

    # run_active_command is called by commander-rb's at_exit hook.
    # We override -- monkey patch -- it to do other stuff.
    alias :old_run_active_command :run_active_command
    def run_active_command
      if @command_exit
        exit @command_exit
      end
      section = active_command.name
      hooked = MrMurano::Hooked.new(section)
      hooked.check_run_pre_hook

      begin
        old_run_active_command
      rescue MrMurano::ConfigError => err
        # Clear whirly if it was running.
        MrMurano::Verbose::whirly_stop
        MrMurano::Verbose::error err.message
        exit 1
      rescue StandardError => err
        raise
      end

      hooked.check_run_post_hook
    end

    alias :old_parse_global_options :parse_global_options
    def parse_global_options
      defopts = ($cfg["#{active_command.name}.options"] or '').split
      @args.push( *defopts )
      old_parse_global_options
    end

    # Weird. --help doesn't work if other flags also specified.
    # E.g., this shows the help for usage:
    #   $ murano --help usage
    # but if a flag is added, the command gets run, e.g.,
    #   $ murano usage --ids 1234 --help
    # ignore the --help and runs the usage command.
    # ([lb] walked the code and it looks like when Commander tries to
    # validate the args, it doesn't like the --ids flag (maybe because
    # the "help" command is being used to validate?). Then it removes
    # the --ids flags (after --help was previously removed) and tries
    # the command *again* (in gems/commander-4.4.3/lib/commander/runner.rb,
    # look for the comment, "Remove the offending args and retry").
    #
    # 2017-06-14: [lb] tried override run! here to show help correctly
    # in this use case, but I could not get it to work. Oh, well... a
    # minor annoyance; just live with it, I guess.
  end
end

#  vim: set ai et sw=2 ts=2 :
