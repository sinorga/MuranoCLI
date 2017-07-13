require 'pathname'
require 'shellwords'
require 'timeout'
require 'tmpdir'
require 'MrMurano/Config'

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
    # The spinner output would make it hard to write expects().
    args.push '--no-progress'

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
    # MUR-XXXX: Product name must be lowercase.
    # 2017-06-01: From [cr]: "I'll be having bizapi convert to lower case
    #  in the short term, and pegasus is updating to allow upper case."
    #  LATER: Remove .downcase once PAAS fixed.
    "#{name.downcase}#{Random.new.rand.hash.abs.to_s(16)}"
  end

  def mk_symlink
    # Make it easy to debug tests, e.g., add breakpoint before capcmd('murano', ...)
    # run test, then open another terminal window and `cd /tmp/murcli-test`.
    # NOTE: When run on Jenkins, Dir.tmpdir() returns the path to the project directory!
    #   Since this is for DEVs only, we can hack around this.
    tmpdir = Dir.tmpdir()
    return unless tmpdir == '/tmp'
    @dev_symlink = File.join(tmpdir, "murcli-test")
    FileUtils.rm(@dev_symlink, :force => true)
    begin
      FileUtils.ln_s(Dir.pwd, @dev_symlink)
    rescue NotImplementedError => err
      # This happens on Windows...
      require 'rbconfig'
      # Check the platform, e.g., "linux-gnu", or other.
      is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
      $stderr.puts(
        "Unexpected: ln_s failed on non-Windows machine / host_os: #{RbConfig::CONFIG['host_os']} / err: #{err}"
      ) unless is_windows
    end
  end

  def rm_symlink
    FileUtils.rm(@dev_symlink, :force => true)
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
          mk_symlink
          Timeout::timeout(300) do
            ex.run
          end
          rm_symlink
        end
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
