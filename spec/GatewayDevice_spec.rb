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

  it "enables one"
  it "removes one"

  context "activates" do
    it "succeeds"
    it "was already activated"
    it "wasn't enabled"
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
