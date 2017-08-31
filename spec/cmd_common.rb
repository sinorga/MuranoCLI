# Last Modified: 2017.08.31 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'highline'
# Set HighLine's $terminal global.
require 'highline/import'
require 'pathname'
require 'shellwords'
require 'timeout'
require 'tmpdir'
require 'webmock/rspec'

require 'MrMurano/Config'

RSpec.shared_context 'CI_CMD' do
  # capcmd makes an Open3-ready `murano` command from a list of args.
  def capcmd(*args)
    args = [args] unless args.is_a? Array
    args.flatten!
    testdir = File.realpath(@testdir.to_s)
    if ENV['CI_MR_EXE'].nil?
      args[0] = File.join(testdir, 'bin', args[0])
      args.unshift('ruby', "-I#{File.join(testdir, 'lib')}")
    else
      args[0] = File.join(testdir, (args[0] + '.exe'))
    end
    args.push '--trace'
    args.push '-c', 'fullerror'
    # The spinner output would make it hard to write expects().
    args.push '--no-progress'

    if Gem.win_platform?
      cmd = args.map do |i|
        case i
        when /[ ]/
          %("#{i}")
        when /[\*#]/
          i.gsub(/([\*#])/, '^\1')
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

  # *** Utility fcns: symlinks.

  # Makes a symlink to the /tmp project dir.
  def mk_symlink
    # Make it easy to debug tests, e.g., add breakpoint before capcmd('murano', ...)
    # run test, then open another terminal window and `cd /tmp/murcli-test`.
    # NOTE: When run on Jenkins, Dir.tmpdir() returns the path to the project directory!
    #   Since this is for DEVs only, we can hack around this.
    tmpdir = Dir.tmpdir()
    return unless tmpdir == '/tmp'
    @dev_symlink = File.join(tmpdir, 'murcli-test')
    FileUtils.rm(@dev_symlink, force: true)
    begin
      FileUtils.ln_s(Dir.pwd, @dev_symlink)
    rescue NotImplementedError => err
      # This happens on Windows...
      require 'rbconfig'
      # Check the platform, e.g., "linux-gnu", or other.
      is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
      unless is_windows
        $stderr.puts(
          'Unexpected: ln_s failed on non-Windows machine / ' \
          "host_os: #{RbConfig::CONFIG['host_os']} / err: #{err}"
        )
      end
    end
  end

  # Removes the /tmp project directory symlink.
  def rm_symlink
    FileUtils.rm(@dev_symlink, force: true) if defined?(@dev_symlink)
  end

  # Utility fcns: Strings.

  # rname makes a random Murano-acceptable Solution name.
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

  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
  end

  # Around: Make project dir under /tmp.
  around(:example) do |ex|
    # Load the byebug library now, before changing directories.
    # This sets Setting[:histfile]. Within byebug, try `show histfile`.
    # Make sure this is set now, otherwise, byebug crashes, e.g.,
    #   <Errno::ENOENT: No such file or directory @ rb_sysopen -
    #       /tmp/d20170830-10087-h7tq6a/project/.byebug_history>
    # This happens if the first call to byebug is after the chdir.
    # Byebug creates the histfile in the tmp dir. So the next time
    # the method containing `byebug` is called, it's from within a
    # different tmp dir, and the old tmp dir has been removed. So
    # byebug crashes trying to access the old, missing histfile.
    require 'byebug/settings/histfile'
    _ignored = ::Byebug::HistfileSetting::DEFAULT

    @testdir = Pathname.new(Dir.pwd).realpath
    Dir.mktmpdir do |hdir|
      ENV['HOME'] = hdir
      Dir.chdir(hdir) do
        Dir.mkdir('.murano')
        @tmpdir = File.join(hdir, 'project')
        Dir.mkdir(@tmpdir)
        Dir.chdir(@tmpdir) do
          mk_symlink
          # Timeout after 300 secs/5 mins.
          Timeout.timeout(300) do
            ex.run
          end
          rm_symlink
        end
      end
    end
  end
end

