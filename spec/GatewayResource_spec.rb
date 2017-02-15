require 'fileutils'
require 'MrMurano/version'
require 'MrMurano/Gateway'
require '_workspace'

RSpec.describe MrMurano::Gateway::Resources do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['project.id'] = 'XYZ'

    @gw = MrMurano::Gateway::Resources.new
    allow(@gw).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @gw.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/")
  end

  it "lists" do
    resources = [
      {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
      {:format=>"string", :unit=>"c", :settable=>true, :alias=>"fuzz"},
      {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"}
    ]
    body = { :resources => {
      :bob=>{:format=>"string", :unit=>"c", :settable=>true},
      :fuzz=>{:format=>"string", :unit=>"c", :settable=>true},
      :gruble=>{:format=>"string", :unit=>"bits", :settable=>true}
    }}
    stub_request(:get, 'https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway').
      to_return(:body=>body.to_json)

    ret = @gw.list
    expect(ret).to eq(resources)
  end

  it "uploads all" do
    res_before = [
      {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
      {:format=>"string", :unit=>"c", :settable=>true, :alias=>"fuzz"},
      {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"}
    ]
    res_after = {
      :bob=>{:format=>"string", :unit=>"c", :settable=>true},
      :fuzz=>{:format=>"string", :unit=>"c", :settable=>true},
      :gruble=>{:format=>"string", :unit=>"bits", :settable=>true}
    }
    stub_request(:patch, 'https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/').
      with(:body=>{:resources=>res_after}.to_json)

    ret = @gw.upload_all(res_before)
    expect(ret).to eq({})
  end

  context "compares" do
    before(:example) do
      @iA = {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"}
      @iB = {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"}
    end
    it "Are equal" do
      ret = @gw.docmp(@iA, @iB)
      expect(ret).to eq(false)
    end
  end

  context "Lookup functions" do
    it "local path is into" do
      ret = @gw.tolocalpath('bob', 'rich')
      expect(ret).to eq('bob')
    end

    it "gets synckey" do
      ret = @gw.synckey({ :alias=>'bob' })
      expect(ret).to eq("bob")
    end
  end

  context "local items" do
    it "succeeds" do
      resfile = Pathname.new('resources.yaml')
      src = File.join(@testdir, 'spec','fixtures','gateway_resource_files', 'resources.yaml')
      FileUtils.copy(src, resfile.to_path)
      ret = @gw.localitems(resfile)
      expect(ret).to eq([
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"fuzz"},
        {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"}
      ])
    end

    it "missing file" do
      resfile = Pathname.new('resources.yaml')
      saved = $stderr
      $stderr = StringIO.new
      ret = @gw.localitems(resfile)
      expect(ret).to eq([])
      expect($stderr.string).to eq("\e[33mSkipping missing resources.yaml\e[0m\n")
      $stderr = saved
    end

    it "isn't a file" do
      resfile = Pathname.new('resources.yaml')
      FileUtils.mkpath('resources.yaml')
      saved = $stderr
      $stderr = StringIO.new
      ret = @gw.localitems(resfile)
      expect(ret).to eq([])
      expect($stderr.string).to eq("\e[33mCannot read from resources.yaml\e[0m\n")
      $stderr = saved
    end

    it "isn't yaml" do
      resfile = Pathname.new('resources.yaml')
      src = File.join(@testdir, 'spec','fixtures','gateway_resource_files', 'resources.notyaml')
      FileUtils.copy(src, resfile.to_path)
      expect{ @gw.localitems(resfile) }.to raise_error(JSON::Schema::ValidationError)
    end

    it "isn't valid" do
      resfile = Pathname.new('resources.yaml')
      src = File.join(@testdir, 'spec','fixtures','gateway_resource_files', 'resources.notyaml')
      FileUtils.copy(src, resfile.to_path)
      expect{ @gw.localitems(resfile) }.to raise_error(JSON::Schema::ValidationError)
    end
  end

  context "syncup" do
    before(:example) do
      expect(@gw).to receive(:list).once.and_return([
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"fuzz"},
        {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"}
      ])
    end
    it "removes keys" do
      expect(@gw).to receive(:upload_all).with([
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
        {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"}
      ])

      @gw.syncup_before
      @gw.remove('fuzz')
      @gw.syncup_after
    end

    it "adds keys" do
      expect(@gw).to receive(:upload_all).with([
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"fuzz"},
        {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"},
        {:format=>"number", :unit=>"bibs", :settable=>false, :alias=>"greeble"},
      ])

      @gw.syncup_before
      @gw.upload(nil, {:format=>"number", :unit=>"bibs", :settable=>false, :alias=>"greeble"}, nil)
      @gw.syncup_after
    end

    it "replaces keys" do
      expect(@gw).to receive(:upload_all).with([
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
        {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"},
        {:format=>"number", :unit=>"bibs", :settable=>false, :alias=>"fuzz"},
      ])

      @gw.syncup_before
      @gw.upload(nil, {:format=>"number", :unit=>"bibs", :settable=>false, :alias=>"fuzz"}, nil)
      @gw.syncup_after
    end
  end

  context "syncdown" do
    before(:example) do
      expect(@gw).to receive(:locallist).once.and_return([
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"bob"},
        {:format=>"string", :unit=>"c", :settable=>true, :alias=>"fuzz"},
        {:format=>"string", :unit=>"bits", :settable=>true, :alias=>"gruble"}
      ])

      @io = instance_double("IO")
      @p = instance_double('Pathname')
      expect(@p).to receive(:open).and_yield(@io)
    end
    it "removes keys" do
      expect(@io).to receive(:write) do |args|
        fy = YAML.load(args)
        expect(fy).to eq({
          'bob'=>{'format'=>"string", 'unit'=>"c", 'settable'=>true},
          'gruble'=>{'format'=>"string", 'unit'=>"bits", 'settable'=>true}
        })
      end

      @gw.syncdown_before(@p)
      @gw.removelocal(@p, {:alias=>'fuzz'})
      @gw.syncdown_after(@p)
    end

    it "adds keys" do
      expect(@io).to receive(:write) do |args|
        fy = YAML.load(args)
        expect(fy).to eq({
          'bob'=>{'format'=>"string", 'unit'=>"c", 'settable'=>true},
          'gruble'=>{'format'=>"string", 'unit'=>"bits", 'settable'=>true},
          'fuzz'=>{'format'=>"string", 'unit'=>"c", 'settable'=>true},
          'greeble'=>{'format'=>"number", 'unit'=>"bibs", 'settable'=>false},
        })
      end

      @gw.syncdown_before(@p)
      @gw.download(@pl, {:format=>"number", :unit=>"bibs", :settable=>false, :alias=>"greeble"})
      @gw.syncdown_after(@p)
    end

    it "replaces keys" do
      expect(@io).to receive(:write) do |args|
        fy = YAML.load(args)
        expect(fy).to eq({
          'bob'=>{'format'=>"string", 'unit'=>"c", 'settable'=>true},
          'gruble'=>{'format'=>"string", 'unit'=>"bits", 'settable'=>true},
          'fuzz'=>{'format'=>"number", 'unit'=>"bibs", 'settable'=>false},
        })
      end

      @gw.syncdown_before(@p)
      @gw.download(@pl, {:format=>"number", :unit=>"bibs", :settable=>false, :alias=>"fuzz"})
      @gw.syncdown_after(@p)
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
