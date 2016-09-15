require 'MrMurano/version'
require 'MrMurano/verbosing'
require 'MrMurano/http'
require 'MrMurano/Product'
require 'MrMurano/configFile'

RSpec.describe MrMurano::Product, "#product" do
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @prd = MrMurano::ProductContent.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")

    @urlroot = "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/provision/manage/content/XYZ"
  end

  it "lists nothing" do
    stub_request(:get, @urlroot + "/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @prd.list
    expect(ret).to eq([])
  end

end

#  vim: set ai et sw=2 ts=2 :
