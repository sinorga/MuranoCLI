require 'pathname'
require 'shellwords'
require 'timeout'
require 'tmpdir'

RSpec.shared_context "CI_CMD" do
  def capcmd(*args)
    args = [args] unless args.kind_of? Array
    args.flatten!
    if ENV['CI_MR_EXE'].nil? then
      args[0] = @testdir + 'bin' + args[0]
      args.unshift("ruby", "-I#{(@testdir+'lib').to_s}")
    else
      args[0] = @testdir + (args[0] + '.exe')
    end
    cmd = Shellwords.join(args)
    #pp cmd
    cmd
  end

  around(:example) do |ex|
    @testdir = Pathname.new(Dir.pwd).realpath
    Dir.mktmpdir do |hdir|
      ENV['HOME'] = hdir
      Dir.chdir(hdir) do
        @tmpdir = File.join(hdir, 'project')
        Dir.mkdir(@tmpdir)
        Dir.chdir(@tmpdir) do
          Timeout::timeout(10) do
            ex.run
          end
        end
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
