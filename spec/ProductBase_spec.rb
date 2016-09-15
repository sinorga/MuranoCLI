require 'MrMurano/version'
require 'MrMurano/verbosing'
require 'MrMurano/http'
require 'MrMurano/Product'
require 'MrMurano/configFile'

RSpec.describe MrMurano::ProductBase, "#product_base" do
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @prd = MrMurano::ProductBase.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @prd.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/product/XYZ/")
  end

  it "can get" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "Fooo")

    ret = @prd.get('/')
    expect(ret).to eq("Fooo")
  end

  it "returns hash when getting empty body" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @prd.get('/')
    expect(ret).to eq({})
  end
end

#  vim: set ai et sw=2 ts=2 :
