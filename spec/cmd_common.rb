require 'pathname'
require 'shellwords'
require 'timeout'
require 'tmpdir'

RSpec.shared_context "CI_CMD" do
  def capcmd(*args)
    args = [args] unless args.kind_of? Array
    args.flatten!
    testdir = File.realpath(@testdir.to_s)
    if ENV['CI_MR_EXE'].nil? then
      args[0] = File.join(testdir, 'bin', args[0])
      args.unshift("ruby", "-I#{File.join(testdir, 'lib')}")
    else
      args[0] = File.join(testdir, (args[0] + '.exe'))
    end

    if Gem.win_platform? then
      cmd = args.map{|i| if i =~ / / then %{"#{i}"} else i end}.join(' ')
    else
      cmd = Shellwords.join(args)
    end
    #pp cmd
    cmd
  end

  around(:example) do |ex|
    @testdir = Pathname.new(Dir.pwd).realpath
    Dir.mktmpdir do |hdir|
      ENV['HOME'] = hdir
      Dir.chdir(hdir) do
        Dir.mkdir('.murano')
        unless ENV['MURANO_USER'].nil? then
          File.open(File.join('.murano', 'config'), 'a') do |io|
            io << "[user]\n"
            io << "name = #{ENV['MURANO_USER']}\n"
          end
        end
        @tmpdir = File.join(hdir, 'project')
        Dir.mkdir(@tmpdir)
        Dir.chdir(@tmpdir) do
          Timeout::timeout(300) do
            ex.run
          end
        end
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
