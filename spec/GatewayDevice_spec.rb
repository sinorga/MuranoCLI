require 'fileutils'
require 'MrMurano/version'
require 'MrMurano/Gateway'
require '_workspace'

RSpec.describe MrMurano::Gateway::Device do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['project.id'] = 'XYZ'

    @gw = MrMurano::Gateway::Device.new
    allow(@gw).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @gw.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/device/")
  end

  context "listing" do
    it "lists" do
      body = {
        :mayLoadMore=>false,
        :devices=>
        [{:identity=>"58",
          :auth=>{:type=>"cik"},
          :state=>{},
          :locked=>false,
          :reprovision=>false,
          :devmode=>false,
          :lastip=>"",
          :lastseen=>1487021743864000,
          :status=>"provisioned",
          :online=>false},
         {:identity=>"56",
          :auth=>{:type=>"cik"},
          :state=>{},
          :locked=>false,
          :reprovision=>false,
          :devmode=>false,
          :lastip=>"",
          :lastseen=>1487021650584000,
          :status=>"provisioned",
          :online=>false},
        ]}
       stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/device").
         to_return(:body=>body.to_json)

      ret = @gw.list
      expect(ret).to eq(body)
    end

    it "lists with limit" do
      body = {
        :mayLoadMore=>false,
        :devices=>
        [{:identity=>"58",
          :auth=>{:type=>"cik"},
          :state=>{},
          :locked=>false,
          :reprovision=>false,
          :devmode=>false,
          :lastip=>"",
          :lastseen=>1487021743864000,
          :status=>"provisioned",
          :online=>false},
        ]}
       stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/device").
         with(:query=>{:limit=>'1'}).
         to_return(:body=>body.to_json)

      ret = @gw.list(1)
      expect(ret).to eq(body)
    end

    it "lists with before" do
      body = {
        :mayLoadMore=>false,
        :devices=>
        [{:identity=>"58",
          :auth=>{:type=>"cik"},
          :state=>{},
          :locked=>false,
          :reprovision=>false,
          :devmode=>false,
          :lastip=>"",
          :lastseen=>1487021743864000,
          :status=>"provisioned",
          :online=>false},
        ]}
       stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/device").
         with(:query=>{:limit=>'1', :before=>'1487021743864000'}).
         to_return(:body=>body.to_json)

      ret = @gw.list(1, 1487021743864000)
      expect(ret).to eq(body)
    end
  end

  it "fetches one" do
    body = {
      :identity=>"58",
      :auth=>{:type=>"cik"},
      :state=>{},
      :locked=>false,
      :reprovision=>false,
      :devmode=>false,
      :lastip=>"",
      :lastseen=>1487021743864000,
      :status=>"provisioned",
      :online=>false}
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/device/58").
      to_return(:body=>body.to_json)

    ret = @gw.fetch(58)
    expect(ret).to eq(body)
  end

  it "enables one" do
    body = {
      :identity=>"58",
      :auth=>{:type=>"cik"},
      :state=>{},
      :locked=>false,
      :reprovision=>false,
      :devmode=>false,
      :lastip=>"",
      :lastseen=>1487021743864000,
      :status=>"provisioned",
      :online=>false}
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/device/58").
      to_return(:body=>body.to_json)

    ret = @gw.enable(58)
    expect(ret).to eq(body)
  end

  it "removes one" do
    body = {
      :identity=>"58",
      :auth=>{:type=>"cik"},
      :state=>{},
      :locked=>false,
      :reprovision=>false,
      :devmode=>false,
      :lastip=>"",
      :lastseen=>1487021743864000,
      :status=>"provisioned",
      :online=>false}
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/device/58").
      to_return(:body=>body.to_json)

    ret = @gw.remove(58)
    expect(ret).to eq(body)
  end

  context "activates" do
    before(:example) do
      @bgw = MrMurano::Gateway::Base.new
      allow(@bgw).to receive(:token).and_return("TTTTTTTTTT")
      expect(MrMurano::Gateway::Base).to receive(:new).and_return(@bgw)
      allow(@gw).to receive(:token).and_return("TTTTTTTTTT")
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway").
        to_return(:body=>{:fqdn=>"xxxxx.m2.exosite-staging.io"}.to_json)
    end
    it "succeeds" do
      stub_request(:post, "https://xxxxx.m2.exosite-staging.io/provision/activate").
        to_return(:body=>'XXXXXXXX')

      ret = @gw.activate(58)
      expect(ret).to eq('XXXXXXXX')
    end

    it "was already activated" do
      stub_request(:post, "https://xxxxx.m2.exosite-staging.io/provision/activate").
        to_return(:status => 409)

      saved = $stderr
      $stderr = StringIO.new

      @gw.activate(58)
      expect($stderr.string).to eq("\e[31mRequest Failed: 409: nil\e[0m\n")
      $stderr = saved
    end

    it "wasn't enabled" do
      stub_request(:post, "https://xxxxx.m2.exosite-staging.io/provision/activate").
        to_return(:status => 404)

      saved = $stderr
      $stderr = StringIO.new

      @gw.activate(58)
      expect($stderr.string).to eq("\e[31mRequest Failed: 404: nil\e[0m\n")
      $stderr = saved
    end
  end

  context "enables batch" do
    it "enables from cvs"
    it "but file is missing"
    it "but file is not text"
    it "but file is malformed csv"
  end

  it "reads state"
  context "writes state" do
    it "succeeds"
    it "fails"
  end

end

#  vim: set ai et sw=2 ts=2 :
