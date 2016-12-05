require 'MrMurano/version'
require 'MrMurano/Config'
require 'tempfile'

RSpec.describe MrMurano::Config::ConfigFile do
  it "Creates a file" do
    tmpfile = Dir.tmpdir + '/cfgtest' # This way because Tempfile.new creates.
    begin
      cf = MrMurano::Config::ConfigFile.new(:user, tmpfile)
      cf.write

      expect(FileTest.exist?(tmpfile))
      unless Gem.win_platform? then
        expect(FileTest.world_readable?(tmpfile)).to be(nil)
        expect(FileTest.world_writable?(tmpfile)).to be(nil)
      end
    ensure
      File.unlink(tmpfile) unless tmpfile.nil?
    end
  end

  it ":internal does not write a file" do
    tmpfile = Dir.tmpdir + '/cfgtest' # This way because Tempfile.new creates.
    begin
      MrMurano::Config::ConfigFile.new(:internal, tmpfile)
      expect(FileTest.exist?(tmpfile)).to be(false)
    ensure
      File.unlink(tmpfile) if FileTest.exist?(tmpfile)
    end
  end
  it ":defaults does not write a file" do
    tmpfile = Dir.tmpdir + '/cfgtest' # This way because Tempfile.new creates.
    begin
      MrMurano::Config::ConfigFile.new(:defaults, tmpfile)
      expect(FileTest.exist?(tmpfile)).to be(false)
    ensure
      File.unlink(tmpfile) if FileTest.exist?(tmpfile)
    end
  end

  it "loads a file" do
      cf = MrMurano::Config::ConfigFile.new(:project, 'spec/fixtures/configfile')
      cf.load

      expect(cf[:data]['solution']['id']).to eq('XXXXXXXXXX')
  end

end

#  vim: set ai et sw=2 ts=2 :
