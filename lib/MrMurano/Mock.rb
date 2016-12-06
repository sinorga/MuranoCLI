require 'erb'
require 'securerandom'

module MrMurano
  class Mock
    attr_accessor :uuid

    def initialize
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
              return capture.captures[0]
            end
          end
        end
      end
      return false
    end

    def get_mock_template
      path = get_mock_template_path()
      testpoint_mock = Pathname.new(path)
      return ::File.read(path)
    end

    def get_mock_template_path
      return ::File.join(::File.dirname(__FILE__), 'template', 'mock.erb')
    end

    def create_testpoint
      uuid = SecureRandom.uuid
      template = ERB.new(get_mock_template)
      endpoint = template.result(binding)
      @testpointfile.open('wb') do |io|
        io << endpoint
      end
      return uuid
    end

    def remove_testpoint
      if @testpointfile.exist? then
        @testpointfile.unlink
        return true
      end
      return false
    end
  end
end
