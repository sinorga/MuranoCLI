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

    @prd = MrMurano::Product.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "returns info" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/info").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: {
         "id"=> "<id>",
         "bizid"=>"<bizid>",
         "label"=> "<label>",
         "endpoint"=> "<endpoint>",
         "rid"=> "<rid>",
         "modelrid"=> "<rid>",
         "resources"=> [{
           "alias"=> "<alias>",
           "format"=> "<format>",
           "rid"=> "<rid>"
         }]
       }.to_json)

      ret = @prd.info()
      expect(ret).to eq({
         :id=> "<id>",
         :bizid=>"<bizid>",
         :label=> "<label>",
         :endpoint=> "<endpoint>",
         :rid=> "<rid>",
         :modelrid=> "<rid>",
         :resources=> [{
           :alias=> "<alias>",
           :format=> "<format>",
           :rid=> "<rid>"
         }]
       })
  end
end

#  vim: set ai et sw=2 ts=2 :
