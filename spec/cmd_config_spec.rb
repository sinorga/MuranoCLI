require 'tmpdir'
require 'open3'
require 'fileutils'

RSpec.describe 'mr config' do

  pref = "ruby -I#{File.join(Dir.pwd, 'lib')} #{File.join(Dir.pwd,'bin/')}"
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
    out, err, status = Open3.capture3("#{pref}mr config")
    expect(status).to eq(0)
    expect(out).to eq("\e[31mNeed a config key\e[0m\n")
    expect(err).to eq('')
  end

  it "Sets a key" do
    out, err, status = Open3.capture3("#{pref}mr config bob build")
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')
  end

  it "Reads a key" do
    FileUtils.copy_file(File.join(@testdir, 'spec','fixtures','.mrmuranorc'),
                        File.join(@tmpdir, '.mrmuranorc'),
                        :verbose => true)
    out, err, status = Open3.capture3("#{pref}mr config --project doThisTest.bob")
    expect(status).to eq(0)
    expect(out).to eq("build\n")
    expect(err).to eq('')
  end

  it "Removes a key" do
    rcf = File.join(@tmpdir, '.mrmuranorc')
    tcf = File.join(@testdir, 'spec','fixtures','.mrmuranorc')
    FileUtils.copy_file(tcf, rcf, :verbose => true)
    out, err, status = Open3.capture3(%{#{pref}mr config --project --unset doThisTest.bob})
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(rcf)
    bfile = IO.read(File.join(@testdir, 'spec','fixtures','mrmuranorc_deleted_bob'))
    expect(afile).to eq(bfile)
  end
end

#  vim: set ai et sw=2 ts=2 :
