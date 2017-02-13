require 'MrMurano/SubCmdGroupContext'

command :project do |c|
  c.syntax = %{murano prject}
  c.summary = %{About projects}
  c.description = %{Sub-commands for working with projects}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

#  vim: set ai et sw=2 ts=2 :
