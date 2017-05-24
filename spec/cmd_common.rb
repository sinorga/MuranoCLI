require 'MrMurano/Config'
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
    args.push '--trace'
    args.push '-c', 'fullerror'

    if Gem.win_platform? then
      cmd = args.map do |i|
        case i
        when /[ ]/
          %{"#{i}"}
        when /[\*#]/
          i.gsub(/([\*#])/,'^\1')
        else
          i
        end
      end.join(' ')
    else
      cmd = Shellwords.join(args)
    end
    #pp cmd
    cmd
  end

  def rname(name)
    #"#{name}-#{Random.new.rand.hash.abs.to_s(16)}"
    # MUR-2454: Product name may only contain letters and numbers.
    #"#{name}#{Random.new.rand.hash.abs.to_s(16)}"
    # MUR-XXXX: Product name must be same as business ID??
    $cfg['business.id']
  end

  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
  end

  around(:example) do |ex|
    @testdir = Pathname.new(Dir.pwd).realpath
    Dir.mktmpdir do |hdir|
      ENV['HOME'] = hdir
      Dir.chdir(hdir) do
        Dir.mkdir('.murano')
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
