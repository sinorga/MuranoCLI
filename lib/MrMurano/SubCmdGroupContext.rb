
module MrMurano
  class SubCmdGroupHelp
    attr :name, :description

    def initialize(command)
      @name = command.syntax.to_s
      @description = command.description.to_s
      @runner = ::Commander::Runner.instance
      prefix = /^#{command.name.to_s} /
      cmds = @runner.instance_variable_get(:@commands).select{|n,_| n.to_s =~ prefix}
      @commands = cmds
      als = @runner.instance_variable_get(:@aliases).select{|n,_| n.to_s =~ prefix}
      @aliases = als

      @options = {}
    end

    def program(key)
      case key
      when :name
        @name
      when :description
        @description
      when :help
        nil
      else
        nil
      end
    end

    def alias?(name)
      @aliases.include? name.to_s
    end

    def command(name)
      @commands[name.to_s]
    end

    def get_help
      hf = @runner.program(:help_formatter).new(self)
      pc = Commander::HelpFormatter::ProgramContext.new(self).get_binding
      hf.template(:help).result(pc)
    end
  end
end


#  vim: set ai et sw=2 ts=2 :
