require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Account'
require 'highline/import'
require '_workspace'

RSpec.describe MrMurano::Account, "token" do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['business.id'] = 'XYZxyz'
    $cfg['product.id'] = 'XYZ'

    @acc = MrMurano::Account.new
  end

  after(:example) do
    @acc.token_reset
  end

  context "Get login info" do
    before(:example) do
      @pswd = instance_double("MrMurano::Passwords")
      allow(@pswd).to receive(:load).and_return(nil)
      allow(@pswd).to receive(:save).and_return(nil)
      allow(MrMurano::Passwords).to receive(:new).and_return(@pswd)
    end

    it "Asks for nothing" do
      $cfg['user.name'] = "bob"
      expect(@pswd).to receive(:get).once.and_return("built")

      ret = @acc._loginInfo
      expect(ret).to eq({
        :email => "bob", :password=>"built"
      })
    end

    it "Asks for user name" do
      $cfg['user.name'] = nil
      expect($terminal).to receive(:ask).once.and_return('bob')
      expect(@acc).to receive(:error).once
      expect($cfg).to receive(:set).with('user.name', 'bob', :user).once.and_call_original
      expect(@pswd).to receive(:get).once.and_return("built")

      ret = @acc._loginInfo
      expect(ret).to eq({
        :email => "bob", :password=>"built"
      })
    end

    it "Asks for password" do
      $cfg['user.name'] = "bob"
      expect(@pswd).to receive(:get).with('bizapi.hosted.exosite.io','bob').once.and_return(nil)
      expect(@acc).to receive(:error).once
      expect($terminal).to receive(:ask).once.and_return('dog')
      expect(@pswd).to receive(:set).once.with('bizapi.hosted.exosite.io','bob','dog')

      ret = @acc._loginInfo
      expect(ret).to eq({
        :email => "bob", :password=>"dog"
      })
    end
  end

  context "token" do
    before(:example) do
      allow(@acc).to receive(:_loginInfo).and_return({:email=>'bob',:password=>'v'})
    end

    it "gets a token" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/token/").
        with(:body => {:email=>'bob', :password=>'v'}.to_json).
        to_return(body: {:token=>"ABCDEFGHIJKLMNOP"}.to_json )

      ret = @acc.token
      expect(ret).to eq("ABCDEFGHIJKLMNOP")
    end

    it "gets an error" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/token/").
        with(:body => {:email=>'bob', :password=>'v'}.to_json).
        to_return(status: 401, body: {}.to_json )

      expect(@acc).to receive(:error).twice.and_return(nil)
      ret = @acc.token
      expect(ret).to be_nil
    end

    it "uses existing token" do
      @acc.token_reset("quxx")
      ret = @acc.token
      expect(ret).to eq("quxx")
    end

    it "uses existing token, even with new instance" do
      @acc.token_reset("quxx")
      acc = MrMurano::Account.new
      ret = acc.token
      expect(ret).to eq("quxx")
    end
  end
end

RSpec.describe MrMurano::Account do
  include_context "WORKSPACE"
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

  context "lists business" do
    it "for user.name" do
      bizlist = [{"bizid"=>"XXX","role"=>"admin","name"=>"MPS"},
                 {"bizid"=>"YYY","role"=>"admin","name"=>"MAE"}]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/user/BoB@place.net/membership/").
        to_return(body: bizlist )

      $cfg['user.name'] = 'BoB@place.net'
      ret = @acc.businesses
      expect(ret).to eq(bizlist)
    end

    it "askes for account when missing" do
      bizlist = [{"bizid"=>"XXX","role"=>"admin","name"=>"MPS"},
                 {"bizid"=>"YYY","role"=>"admin","name"=>"MAE"}]
      ret = @acc.businesses
      expect(ret).to eq(bizlist)
    end
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
    expect { @acc.products }.to raise_error("Missing Business ID")
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
    expect { @acc.new_product("ONe") }.to raise_error("Missing Business ID")
  end

  it "deletes product" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/product/ONe").
      to_return(body: "" )

    ret = @acc.delete_product("ONe")
    expect(ret).to eq({})
  end

  it "deletes product; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.delete_product("ONe") }.to raise_error("Missing Business ID")
  end


  it "lists solutions" do
    sollist = [{"bizid"=>"XYZxyz",
                "type"=>"dataApi",
                "domain"=>"two.apps.exosite.io",
                "apiId"=>"abc",
                "sid"=>"def"},
               {"bizid"=>"XYZxyz",
                "type"=>"dataApi",
                "domain"=>"one.apps.exosite.io",
                "apiId"=>"ghi",
                "sid"=>"jkl"}]
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      to_return(body: sollist )

    ret = @acc.solutions
    expect(ret).to eq(sollist)
  end

  it "lists solutions; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.solutions }.to raise_error("Missing Business ID")
  end

  it "creates solution" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      with(:body => {:label=>'one', :type=>'dataApi'}).
      to_return(body: "" )

    ret = @acc.new_solution("one")
    expect(ret).to eq({})
  end

  it "creates solution; with upper case" do
    expect { @acc.new_solution("ONe") }.to raise_error("Solution name must be lowercase")
  end

  it "creates solution; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.new_solution("one") }.to raise_error("Missing Business ID")
  end

  it "deletes solution" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/one").
      to_return(body: "" )

    ret = @acc.delete_solution("one")
    expect(ret).to eq({})
  end

  it "deletes solution; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.delete_solution("one") }.to raise_error("Missing Business ID")
  end

end

#  vim: set ai et sw=2 ts=2 :
