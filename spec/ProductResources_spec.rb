require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Product-Resources'

RSpec.describe MrMurano::ProductResources do
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['product.spec'] = 'XYZ.yaml'

    @prd = MrMurano::ProductResources.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
    allow(@prd).to receive(:model_rid).and_return("LLLLLLLLLL")
  end

  it "initializes" do
    uri = @prd.endPoint('')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process")
  end

  context "location" do
    it "Gets a product.spec, with location.specs" do
      loc = @prd.location
      expect(loc).to eq("specs/XYZ.yaml")
    end
    it "Gets a product.spec, without location.specs" do
      $cfg.set('location.specs', nil, :defaults)
      loc = @prd.location
      expect(loc).to eq("XYZ.yaml")
    end

    it "Gets a p-FOO.spec, with location.specs" do
      $cfg['p-XYZ.spec'] = 'magical.file'
      loc = @prd.location
      expect(loc).to eq("specs/magical.file")
    end

    it "Gets a p-FOO.spec, without location.specs" do
      $cfg['p-XYZ.spec'] = 'magical.file'
      $cfg.set('location.specs', nil, :defaults)
      loc = @prd.location
      expect(loc).to eq("magical.file")
    end

    it "raises when no spec name" do
      $cfg['product.spec'] = nil
      $cfg['product.id'] = nil
      expect { @prd.location }.to raise_error("No spec file named; run `mr config prodcut.spec <specfile>`")
    end
  end


  context "queries" do
    it "gets info" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"info",
                              :arguments=>["LLLLLLLLLL", {}]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:comments=>[]}}])

      ret = @prd.info
      expect(ret).to eq({:comments=>[]})
    end

    it "gets listing" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"info",
                              :arguments=>["LLLLLLLLLL", {}]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:aliases=>{:abcdefg=>["bob"]}}}])

      ret = @prd.list
      expect(ret).to eq([{:alias=>"bob", :rid=>:abcdefg}])
    end
  end

  context "Modifying" do
    it "Drops RID" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"drop",
                              :arguments=>["abcdefg"]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{}}])

      ret = @prd.remove("abcdefg")
      expect(ret).to eq({})
    end

    it "Creates" do
      frid = "ffffffffffffffffffffffffffffffffffffffff"
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"create",
                              :arguments=>["dataport",{
                                :format=>"string",
                                :name=>"bob",
                                :retention=>{
                                  :count=>1,
                                  :duration=>"infinity"
                                }
                              }]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>frid}])

      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"map",
                              :arguments=>["alias", frid, "bob"]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{}}])

      ret = @prd.create("bob")
      expect(ret).to eq({})
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
