require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Account'

RSpec.describe MrMurano::Account do
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['business.id'] = 'XYZxyz'
    $cfg['product.id'] = 'XYZ'

    @acc = MrMurano::Account.new
    allow(@acc).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @acc.endPoint('')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/")
  end

  it "lists bussiness" do
    bizlist = [{"bizid"=>"XXX","role"=>"admin","name"=>"MPS"},
                       {"bizid"=>"YYY","role"=>"admin","name"=>"MAE"}]
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/user/BoB@place.net/membership/").
      to_return(body: bizlist )

    $cfg['user.name'] = 'BoB@place.net'
    ret = @acc.businesses
    expect(ret).to eq(bizlist)
  end

  it "lists products" do
    prdlist = [{"bizid"=>"XYZxyz","type"=>"onepModel","pid"=>"ABC","modelId"=>"cde","label"=>"fts"},
               {"bizid"=>"XYZxyz","type"=>"onepModel","pid"=>"fgh","modelId"=>"ijk","label"=>"lua-test"}]
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/product/").
      to_return(body: prdlist )

    ret = @acc.products
    expect(ret).to eq(prdlist)
  end

  it "lists products; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.products }.to raise_error("Missing Bussiness ID")
  end

  it "creates product" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/product/").
      with(:body => {:label=>'ONe', :type=>'onepModel'}).
      to_return(body: "" )

    ret = @acc.new_product("ONe")
    expect(ret).to eq({})
  end

  it "creates product; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.new_product("ONe") }.to raise_error("Missing Bussiness ID")
  end

  it "deletes product" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/product/ONe").
      to_return(body: "" )

    ret = @acc.delete_product("ONe")
    expect(ret).to eq({})
  end

  it "deletes product; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.delete_product("ONe") }.to raise_error("Missing Bussiness ID")
  end


  it "lists solutions"
  it "lists solutions; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.solutions }.to raise_error("Missing Bussiness ID")
  end

  it "creates solution"
  it "creates solution; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.new_solution("one") }.to raise_error("Missing Bussiness ID")
  end

  it "deletes solution"
  it "deletes solution; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.delete_solution("one") }.to raise_error("Missing Bussiness ID")
  end

end

#  vim: set ai et sw=2 ts=2 :
