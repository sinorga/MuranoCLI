require 'MrMurano/Solution-ServiceConfig'
require 'securerandom'

module MrMurano
  class Mock < ServiceConfig
    def initialize
      super
      @serviceName = 'mock'
      @testpoint_file = 'testpoint.post.lua'
      @endpoints = $cfg['location.endpoints']
      @filename = %{#{$cfg['location.endpoints']}/#{@testpoint_file}}
      @testpointfile = Pathname.new(@filename)
    end

    def show
      if @testpointfile.exist? then
        authorization = %{if request.headers["authorization"] == "}
        @testpointfile.open('rb') do |io|
          io.each_line do |line|
            auth_line = line.include?(authorization)
            if auth_line then
              capture = /\=\= "(.*)"/.match(line)
              puts capture.captures[0]
            end
          end
        end
      else
        say %{Could not find testpoint file.}
      end
    end

    def create_testpoint
      uuid = SecureRandom.uuid
      testpoint_api = %{--#ENDPOINT POST /testpoint/{service}/{call}
if request.headers["authorization"] == "#{uuid}" then
  local fn = _G[request.parameters.service][request.parameters.call]
  response.message = fn(request.body)
else
  response.code = 401
  response.message = "invalid authorization header"
end

}

      @testpointfile.open('wb') do |io|
        io << testpoint_api
      end
      say %{Created testpoint file. Run `mr syncup` to activate. The following is the authorization token:}
      say %{$ export AUTHORIZATION="#{uuid}"}
    end

    def remove_testpoint
      if @testpointfile.exist? then
        @testpointfile.unlink
        say %{Deleted testpoint file. Run `mr syncup` to remove the testpoint.}
      else
        say %{testpoint file not present!}
      end
    end
  end
end

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

  c.action do |args, options|
    mock = MrMurano::Mock.new
    mock.create_testpoint()
  end
end

command 'mock disable' do |c|
  c.syntax = %{mr mock disable}
  c.summary = %{Remove the testpoint file.}
  c.description = %{Run syncup after running this to carry the change through to Murano.}

  c.action do |args, options|
    mock = MrMurano::Mock.new
    mock.remove_testpoint()
  end
end

command 'mock show' do |c|
  c.syntax = %{mr mock disable}
  c.summary = %{Remove the testpoint file.}
  c.description = %{Run syncup after running this to carry the change through to Murano.}

  c.action do |args, options|
    mock = MrMurano::Mock.new
    mock.show()
  end
end
