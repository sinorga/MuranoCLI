require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Product-Resources'

RSpec.describe MrMurano::ProductResources do
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @prd = MrMurano::ProductResources.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
    allow(@prd).to receive(:model_rid).and_return("LLLLLLLLLL")
  end

  it "initializes" do
    uri = @prd.endPoint('')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process")
  end

  context "do_rpc" do
    # Note, do_rpc is private.
    it "Accepts an object" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{
        :id=>1, :status=>"ok", :result=>{}
      }])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq({})
    end

    it "Accepts an Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:one=>1}},
      {:id=>2, :status=>"ok", :result=>{:two=>2}}])

      ret = nil
      @prd.instance_eval{ ret = do_rpc([{:id=>1}, {:id=>2}]) }
      expect(ret).to eq({:one=>1})
      # yes it only returns first.
    end

    it "returns res if not Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: {:not=>'an array'}.to_json)

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq({:not=>'an array'})
    end

    it "returns res if count less than 1" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq([])
    end

    it "returns res[0] if not Hash" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: ["foo"])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq("foo")
    end

    it "returns res[0] if not status ok" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>'error'}])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq({:id=>1, :status=>'error'})
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
