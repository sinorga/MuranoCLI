require 'tmpdir'
require 'open3'
require 'fileutils'

RSpec.describe 'mr config' do

  pref = "ruby -Ilib bin/"
  around(:example) do |ex|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      ex.run
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
    FileUtils.copy_file 'spec/fixtures/.mrmuranorc', File.join(@tmpdir, '.mrmuranorc'), :verbose => true
    out, err, status = Open3.capture3("#{pref}mr config --project doThisTest.bob")
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')
  end

  it "Removes a key" do
    rcf = File.join(@tmpdir, '.mrmuranorc')
    FileUtils.copy_file 'spec/fixtures/.mrmuranorc', rcf, :verbose => true
    out, err, status = Open3.capture3(%{#{pref}mr config --project --unset doThisTest.bob})
    expect(status).to eq(0)
    expect(out).to eq('')
    expect(err).to eq('')

    afile = IO.read(rcf)
    bfile = IO.read('spec/fixtures/.mrmuranorc')
    expect(afile).to eq(bfile)
  end
end

#  vim: set ai et sw=2 ts=2 :
