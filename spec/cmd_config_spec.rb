require 'fileutils'
require 'open3'
require 'pathname'
require 'shellwords'
require 'tmpdir'

RSpec.describe 'mr config' do

  $realpwd = Pathname.new(Dir.pwd).realpath
  def capcmd(*args)
    args = [args] unless args.kind_of? Array
    args.flatten!
    args[0] = $realpwd + 'bin' + args[0]
    args.unshift("ruby", "-I#{($realpwd+'lib').to_s}")
    cmd = Shellwords.join(args)
    #pp cmd
    cmd
  end

  around(:example) do |ex|
    @testdir = Dir.pwd
    Dir.mktmpdir do |hdir|
      ENV['HOME'] = hdir
      Dir.chdir(hdir) do
        @tmpdir = File.join(hdir, 'project')
        Dir.mkdir(@tmpdir)
        Dir.chdir(@tmpdir) do
          ex.run
        end
      end
    end
  end

  it "Needs a key" do
    out, err, status = Open3.capture3(capcmd('mr', "config"))
    expect(status).to eq(0)
    expect(out).to eq("\e[31mNeed a config key\e[0m\n")
    expect(err).to eq('')
  end

  it "Sets a key" do
    out, err, status = Open3.capture3(capcmd(%w{mr config bob build}))
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(File.join(@tmpdir, '.mrmuranorc'))
    bfile = IO.read(File.join(@testdir, 'spec','fixtures','mrmuranorc_tool_bob'))
    expect(afile).to eq(bfile)
  end

  it "Sets a user key" do
    out, err, status = Open3.capture3("#{pref}mr config bob build --user")
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(File.join(ENV['HOME'], '.mrmuranorc'))
    bfile = IO.read(File.join(@testdir, 'spec','fixtures','mrmuranorc_tool_bob'))
    expect(afile).to eq(bfile)
  end

  it "Reads a key" do
    FileUtils.copy_file ($realpwd+'spec/fixtures/.mrmuranorc').to_s, File.join(@tmpdir, '.mrmuranorc'), :verbose => true
    out, err, status = Open3.capture3(capcmd(%w{mr config --project doThisTest.bob}))
    expect(status).to eq(0)
    expect(out).to eq("build\n")
    expect(err).to eq('')
  end

  it "Removes a key" do
    rcf = File.join(@tmpdir, '.mrmuranorc')
    FileUtils.copy_file ($realpwd+'spec/fixtures/.mrmuranorc').to_s, rcf, :verbose => true
    out, err, status = Open3.capture3(capcmd(%w{mr config --project --unset doThisTest.bob}))
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(rcf)
    bfile = IO.read(File.join(@testdir, 'spec','fixtures','mrmuranorc_deleted_bob'))
    expect(afile).to eq(bfile)
  end



end

#  vim: set ai et sw=2 ts=2 :
