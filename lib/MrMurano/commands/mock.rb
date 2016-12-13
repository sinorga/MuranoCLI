require 'MrMurano/Mock'

command 'mock' do |c|
  c.syntax = %{mr mock}
  c.summary = %{Enable or disable testpoint. Show current UUID.}
  c.description = %{mock lets you enable testpoints to do local lua development}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'mock enable' do |c|
  c.syntax = %{mr mock enable}
  c.summary = %{Create a testpoint file.}
  c.description = %{Run syncup after running this to carry the change through to Murano.
   Returns the UUID to be used for authenticating.
  }
  c.option '--raw', %{print raw uuid}
  c.action do |args, options|
    mock = MrMurano::Mock.new
    uuid = mock.create_testpoint()
    if options.raw then
      say uuid
    else
      say %{Created testpoint file. Run `mr syncup` to activate. The following is the authorization token:}
      say %{$ export AUTHORIZATION="#{uuid}"}
    end
  end
end

command 'mock disable' do |c|
  c.syntax = %{mr mock disable}
  c.summary = %{Remove the testpoint file.}
  c.description = %{Run syncup after running this to carry the change through to Murano.}

  c.action do |args, options|
    mock = MrMurano::Mock.new
    removed = mock.remove_testpoint()
    if removed then
      say %{Deleted testpoint file. Run `mr syncup` to remove the testpoint.}
    else
      say %{No testpoint file to remove.}
    end
  end
end

command 'mock show' do |c|
  c.syntax = %{mr mock disable}
  c.summary = %{Remove the testpoint file.}
  c.description = %{Run syncup after running this to carry the change through to Murano.}

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
