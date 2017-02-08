require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano config' do
  include_context "CI_CMD"

  it "Needs a key" do
    out, err, status = Open3.capture3(capcmd('murano', "config"))
    expect(status).to eq(0)
    expect(out).to eq("\e[31mNeed a config key\e[0m\n")
    expect(err).to eq('')
  end

  it "Sets a key" do
    out, err, status = Open3.capture3(capcmd(%w{murano config bob build}))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status).to eq(0)

    afile = IO.read(File.join(@tmpdir, '.murano/config'))
    bfile = (@testdir + 'spec' + 'fixtures' + 'mrmuranorc_tool_bob').read
    expect(afile).to eq(bfile)
  end

  it "Sets a user key" do
    out, err, status = Open3.capture3(capcmd(%w{murano config bob build --user}))
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(File.join(ENV['HOME'], '.murano', 'config'))
    bfile = (@testdir + 'spec' + 'fixtures' + 'mrmuranorc_tool_bob').read
    expect(afile).to eq(bfile)
  end

  it "Reads a key" do
    FileUtils.mkpath(File.join(@tmpdir, '.murano'))
    FileUtils.copy_file((@testdir+'spec'+'fixtures'+'.mrmuranorc').to_s,
                        File.join(@tmpdir, '.murano', 'config'),
                        :verbose => true)
    out, err, status = Open3.capture3(capcmd(%w{murano config --project doThisTest.bob}))
    expect(status).to eq(0)
    expect(out).to eq("build\n")
    expect(err).to eq('')
  end

  it "Removes a key" do
    FileUtils.mkpath(File.join(@tmpdir, '.murano'))
    rcf = File.join(@tmpdir, '.murano', 'config')
    FileUtils.copy_file((@testdir+'spec'+'fixtures'+'.mrmuranorc').to_s,
                        rcf, :verbose => true)
    out, err, status = Open3.capture3(capcmd(%w{murano config --project --unset doThisTest.bob}))
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(rcf)
    bfile = (@testdir + 'spec' + 'fixtures' + 'mrmuranorc_deleted_bob').read
    expect(afile).to eq(bfile)
  end

end

#  vim: set ai et sw=2 ts=2 :
