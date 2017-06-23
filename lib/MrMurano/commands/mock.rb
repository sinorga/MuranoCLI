require 'MrMurano/Mock'

command 'mock' do |c|
  c.syntax = %{murano mock}
  c.summary = %{Enable or disable testpoint, or show current UUID}
  c.description = %{
The mock command lets you enable testpoints to do local Lua development.
  }.strip

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'mock enable' do |c|
  c.syntax = %{murano mock enable}
  c.summary = %{Create a testpoint file}
  c.description = %{
Create a testpoint file.

Run syncup after running this to carry the change through to Murano.

Returns the UUID to be used for authenticating.
  }.strip
  c.option '--raw', %{print raw uuid}

  c.action do |args, options|
    mock = MrMurano::Mock.new
    uuid = mock.create_testpoint()
    if options.raw then
      say uuid
    else
      say %{Created testpoint file. Run `murano syncup` to activate. The following is the authorization token:}
      say %{$ export AUTHORIZATION="#{uuid}"}
    end
  end
end

command 'mock disable' do |c|
  c.syntax = %{murano mock disable}
  c.summary = %{Remove the testpoint file}
  c.description = %{
Remove the testpoint file.

Run syncup after running this to carry the change through to Murano.
  }.strip

  c.action do |args, options|
    mock = MrMurano::Mock.new
    removed = mock.remove_testpoint()
    if removed then
      say %{Deleted testpoint file. Run `murano syncup` to remove the testpoint.}
    else
      say %{No testpoint file to remove.}
    end
  end
end

command 'mock show' do |c|
  c.syntax = %{murano mock disable}
  c.summary = %{Remove the testpoint file}
  c.description = %{
Remove the testpoint file.

Run syncup after running this to carry the change through to Murano.
  }.strip

  c.action do |args, options|
    mock = MrMurano::Mock.new
    uuid = mock.show()
    if uuid then
      say uuid
    else
      say %{Could not find testpoint file or UUID in testpoint file.}
    end
  end
end

#  vim: set ai et sw=2 ts=2 :

