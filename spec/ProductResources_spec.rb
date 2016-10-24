require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Product'

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
    it "Accepts an object" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{
        :id=>1, :status=>"ok", :result=>{}
      }])

      ret = @prd.do_rpc({:id=>1})
      expect(ret).to eq({})
    end

    it "Accepts an Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:one=>1}},
      {:id=>2, :status=>"ok", :result=>{:two=>2}}])

      ret = @prd.do_rpc([{:id=>1}, {:id=>2}])
      expect(ret).to eq({:one=>1})
      # yes it only returns first.
    end

    it "returns res if not Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: {:not=>'an array'}.to_json)

      ret = @prd.do_rpc({:id=>1})
      expect(ret).to eq({:not=>'an array'})
    end

    it "returns res if count less than 1" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [])

      ret = @prd.do_rpc({:id=>1})
      expect(ret).to eq([])
    end

    it "returns res[0] if not Hash" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: ["foo"])

      ret = @prd.do_rpc({:id=>1})
      expect(ret).to eq("foo")
    end

    it "returns res[0] if not status ok" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>'error'}])

      ret = @prd.do_rpc({:id=>1})
      expect(ret).to eq({:id=>1, :status=>'error'})
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
