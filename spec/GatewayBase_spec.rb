require 'fileutils'
require 'MrMurano/version'
require 'MrMurano/Gateway'
require '_workspace'

RSpec.describe MrMurano::Gateway::Base do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['project.id'] = 'XYZ'

    @gw = MrMurano::Gateway::Base.new
    allow(@gw).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @gw.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/")
  end

  it "gets info" do
    body = {
      :name=>"XXXXXXXX",
      :protocol=>{:name=>"onep", :auth_type=>"cik"},
      :description=>"XXXXXXXX",
      :identity_format=> {
        :prefix=>"", :type=>"opaque", :options=>{:casing=>"mixed", :length=>0}},
      :fqdn=>"XXXXXXXX.m2.exosite-staging.io",
      :provisioning=> {
        :enabled=>true,
        :generate_identity=>true,
        :presenter_identity=>true,
        :ip_whitelisting=>{:enabled=>false, :allowed=>[]}},
      :resources=> {
          :bob=>{:format=>"string", :unit=>"c", :settable=>true},
          :fuzz=>{:format=>"string", :unit=>"c", :settable=>true},
          :gruble=>{:format=>"string", :unit=>"bits", :settable=>true}
        }
    }
     stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2").
       with(:headers => {'Authorization'=>'token TTTTTTTTTT', 'Content-Type'=>'application/json'}).
       to_return(:status => 200, :body => body.to_json, :headers => {})

    ret = @gw.info
    expect(ret).to eq(body)
  end

end

#  vim: set ai et sw=2 ts=2 :
