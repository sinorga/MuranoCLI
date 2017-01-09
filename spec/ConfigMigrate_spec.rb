require 'MrMurano/version'
require 'MrMurano/Config-Migrate'
require '_workspace'
#require 'tempfile'
#require 'erb'

RSpec.describe MrMurano::ConfigMigrate do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
  end

  context "Basic" do
    before(:example) do
      @lry = Pathname.new(@projectDir) + 'Solutionfile.json'
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/SolutionFiles/basic.json'), @lry.to_path)

      @stdsaved = [$stdout, $stderr]
      $stdout, $stderr = [StringIO.new, StringIO.new]
    end

    after(:example) do
      $stdout, $stderr = @stdsaved
    end

    it "imports data without changing files" do
      $cfg['tool.dry'] = true
      $cfg['tool.verbose'] = true
      cm = MrMurano::ConfigMigrate.new
      cm.load

      allow(cm).to receive(:verbose)
      allow(FileUtils).to receive(:fu_output_message)

      dbefore = Dir['**/*']

      cm.migrate

      dafter = Dir['**/*']

      expect($cfg['location.files']).to eq('public')
      expect($cfg['files.default_page']).to eq('index.html')
      expect($cfg['location.modules']).to eq('modules')
      expect($cfg['location.eventhandlers']).to eq('event_handler')
      expect(dafter).to eq(dbefore) # nothing new created.
    end

    it "imports and modifies things"
  end

end
#  vim: set ai et sw=2 ts=2 :
