require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'mr config' do
  include_context "CI_CMD"

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
    bfile = (@testdir + 'spec' + 'fixtures' + 'mrmuranorc_tool_bob').read
    expect(afile).to eq(bfile)
  end

  it "Sets a user key" do
    out, err, status = Open3.capture3(capcmd(%w{mr config bob build --user}))
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(File.join(ENV['HOME'], '.mrmuranorc'))
    bfile = (@testdir + 'spec' + 'fixtures' + 'mrmuranorc_tool_bob').read
    expect(afile).to eq(bfile)
  end

  it "Reads a key" do
    FileUtils.copy_file((@testdir+'spec'+'fixtures'+'.mrmuranorc').to_s,
                        File.join(@tmpdir, '.mrmuranorc'),
                        :verbose => true)
    out, err, status = Open3.capture3(capcmd(%w{mr config --project doThisTest.bob}))
    expect(status).to eq(0)
    expect(out).to eq("build\n")
    expect(err).to eq('')
  end

  it "Removes a key" do
    rcf = File.join(@tmpdir, '.mrmuranorc')
    FileUtils.copy_file((@testdir+'spec'+'fixtures'+'.mrmuranorc').to_s,
                        rcf, :verbose => true)
    out, err, status = Open3.capture3(capcmd(%w{mr config --project --unset doThisTest.bob}))
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(rcf)
    bfile = (@testdir + 'spec' + 'fixtures' + 'mrmuranorc_deleted_bob').read
    expect(afile).to eq(bfile)
  end

end

#  vim: set ai et sw=2 ts=2 :
