require 'MrMurano/Mock'
require 'tempfile'

RSpec.describe MrMurano::Mock, "#mock" do
  before(:example) do
    @tmpdir = Dir.tmpdir
    @projectDir = @tmpdir + '/home/work/project'

    FileUtils.mkpath(@projectDir)
    FileUtils.mkpath(@projectDir + '/endpoints')
    Dir.chdir(@projectDir) do
      $cfg = MrMurano::Config.new
      $cfg.load
    end

    @mock = MrMurano::Mock.new
  end

  after(:example) do
    FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
  end

  it "can create the testpoint file" do
    Dir.chdir(@projectDir) do
      uuid = @mock.create_testpoint()
      expect(uuid.length).to be("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX".length)
      path = @mock.get_testpoint_path()
      testpoint = File.read(path)
      expect(testpoint.include? uuid).to be(true)
    end
  end

  it "can show the UUID from the testpoint file" do
    Dir.chdir(@projectDir) do
      uuid = @mock.create_testpoint()
      retrieved_uuid = @mock.show()
      expect(uuid).to eq(retrieved_uuid)
    end
  end

  it "can remove the testpoint file" do
    Dir.chdir(@projectDir) do
      @mock.create_testpoint()
      path = @mock.get_testpoint_path()
      removed = @mock.remove_testpoint()
      expect(removed).to be(true)
      expect(File.exist?(path)).to be(false)
    end
  end

  it "cannot show the UUID if there's no testpoint file" do
    Dir.chdir(@projectDir) do
      @mock.create_testpoint()
      @mock.show()
      @mock.remove_testpoint()
      retrieved_uuid = @mock.show()
      expect(retrieved_uuid).to be(false)
    end
  end
end
