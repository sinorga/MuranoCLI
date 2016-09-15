require 'MrMurano/version'
require 'MrMurano/verbosing'
require 'MrMurano/http'
require 'MrMurano/Product'
require 'MrMurano/configFile'

RSpec.describe MrMurano::ProductBase, "#product_base" do
  it "initializes" do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['product.id'] = 'XYZ'
    prd = MrMurano::ProductBase.new

    uri = prd.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/product/XYZ/")
  end
end

#  vim: set ai et sw=2 ts=2 :
