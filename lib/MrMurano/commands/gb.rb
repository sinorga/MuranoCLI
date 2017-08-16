require 'pp'

# You don't need this.
# To use this:
# - mkdir -p ~/.murano/plugins
# - ln gb.rb ~/.murano/plugins

command :_gb do |c|
  c.syntax = %{murano _gb <class> <method> (<args>)}
  c.summary = %{Call internal class methods directly}
  c.description = %{
Call internal class methods directly.
  }.strip
  c.project_not_required = true

  # Will a plugin need to let user restrict the solution type?
  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.action do |args, options|
    cmd_defaults_solntype_pickers(options)

    cls = args[0]
    meth = args[1].to_sym
    args.shift(2)

    begin
      gb = Object::const_get("MrMurano::#{cls}").new
      if gb.respond_to? meth then
        ret = gb.__send__(meth, *args)
        gb.outf(ret) {|o,i| pp o}
      else
        say_error "'#{cls}' doesn't '#{meth}'"
      end
    rescue Exception => e
      say_error e.message
      pp e
    end
  end
end

#  vim: set ai et sw=2 ts=2 :

