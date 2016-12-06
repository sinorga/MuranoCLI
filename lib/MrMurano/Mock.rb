require 'erb'
require 'securerandom'

module MrMurano
  class Mock
    attr_accessor :uuid, :testpoint_file

    def initialize
    end

    def show
      file = Pathname.new(get_testpoint_path)
      if file.exist? then
        authorization = %{if request.headers["authorization"] == "}
        file.open('rb') do |io|
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
      return ::File.read(path)
    end

    def get_testpoint_path
      file_name = 'testpoint.post.lua'
      path = %{#{$cfg['location.endpoints']}/#{file_name}}
      return path
    end

    def get_mock_template_path
      return ::File.join(::File.dirname(__FILE__), 'template', 'mock.erb')
    end

    def create_testpoint
      uuid = SecureRandom.uuid
      template = ERB.new(get_mock_template)
      endpoint = template.result(binding)

      Pathname.new(get_testpoint_path).open('wb') do |io|
        io << endpoint
      end
      return uuid
    end

    def remove_testpoint
      file = Pathname.new(get_testpoint_path)
      if file.exist? then
        file.unlink
        return true
      end
      return false
    end
  end
end
