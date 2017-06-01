require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Account'
require 'highline/import'
require '_workspace'

RSpec.describe MrMurano::Account, "token" do
  include_context "WORKSPACE"
  before(:example) do
    @saved_cfg = ENV['MURANO_CONFIGFILE']
    ENV['MURANO_CONFIGFILE'] = nil
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['business.id'] = 'XYZxyz'
    $cfg['product.id'] = 'XYZ'

    @acc = MrMurano::Account.new
  end

  after(:example) do
    @acc.token_reset
    ENV['MURANO_CONFIGFILE'] = @saved_cfg
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
        to_return(body: {:token=>"ABCDEFGHIJKLMNOP"}.to_json)

      ret = @acc.token
      expect(ret).to eq("ABCDEFGHIJKLMNOP")
    end

    it "gets an error" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/token/").
        with(:body => {:email=>'bob', :password=>'v'}.to_json).
        to_return(status: 401, body: {}.to_json)

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
    @saved_cfg = ENV['MURANO_CONFIGFILE']
    ENV['MURANO_CONFIGFILE'] = nil
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['business.id'] = 'XYZxyz'
    $cfg['product.id'] = 'XYZ'

    @acc = MrMurano::Account.new
    allow(@acc).to receive(:token).and_return("TTTTTTTTTT")
  end
  after(:example) do
    ENV['MURANO_CONFIGFILE'] = @saved_cfg
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
        to_return(body: bizlist)

      $cfg['user.name'] = 'BoB@place.net'
      ret = @acc.businesses
      expect(ret).to eq(bizlist)
    end

    it "askes for account when missing" do
      bizlist = [{"bizid"=>"XXX","role"=>"admin","name"=>"MPS"},
                 {"bizid"=>"YYY","role"=>"admin","name"=>"MAE"}]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/user/BoB@place.net/membership/").
        to_return(body: bizlist)

      $cfg['user.name'] = nil
      expect(@acc).to receive(:_loginInfo) do |arg|
        $cfg['user.name'] = 'BoB@place.net'
      end

      ret = @acc.businesses
      expect(ret).to eq(bizlist)
    end
  end

  # *** :product type solutions

  it "lists products" do
    prdlist = [{"bizid"=>"XYZxyz","type"=>"onepModel","pid"=>"ABC","modelId"=>"cde","label"=>"fts"},
               {"bizid"=>"XYZxyz","type"=>"onepModel","pid"=>"fgh","modelId"=>"ijk","label"=>"lua-test"}]
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      to_return(body: prdlist)

    ret = @acc.products
    expect(ret).to eq(prdlist)
  end

  it "lists products; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect(@acc).to receive(:debug).with("Getting all solutions of type product")
    expect { @acc.products }.to raise_error("Missing Business ID")
  end

  it "creates product" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      with(:body => {:label=>'ONe', :type=>'product'}).
      to_return(body: "")

    ret = @acc.new_product("ONe")
    expect(ret).to eq({})
  end

  it "creates product; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.new_product("ONe") }.to raise_error("Missing Business ID")
  end

  it "deletes product" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/ONe").
      to_return(body: "")

    ret = @acc.delete_product("ONe")
    expect(ret).to eq({})
  end

  it "deletes product; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.delete_product("ONe") }.to raise_error("Missing Business ID")
  end

  # *** :applications type solutions

  it "lists applications" do
    applist = [{"bizid"=>"XYZxyz","type"=>"product","pid"=>"ABC","modelId"=>"cde","label"=>"fts"},
               {"bizid"=>"XYZxyz",
                "type"=>"application",
                "domain"=>"XYZxyz.apps.exosite.io",
                "apiId"=>"ACBabc",
                "sid"=>"ACBabc"},
               {"bizid"=>"XYZxyz",
                "type"=>"application",
                "domain"=>"XYZxyz.apps.exosite.io",
                "apiId"=>"DEFdef",
                "sid"=>"DEFdef"}]
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      to_return(body: applist)

    ret = @acc.applications
    expect(ret).to eq(applist)
  end

  it "lists applications; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect(@acc).to receive(:debug).with("Getting all solutions of type application")
    expect { @acc.applications }.to raise_error("Missing Business ID")
  end

  it "creates application" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      with(:body => {:label=>'ONe', :type=>'application'}).
      to_return(body: "")

    ret = @acc.new_application("ONe")
    expect(ret).to eq({})
  end

  it "creates application; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.new_application("ONe") }.to raise_error("Missing Business ID")
  end

  it "deletes application" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/ONe").
      to_return(body: "")

    ret = @acc.delete_application("ONe")
    expect(ret).to eq({})
  end

  it "deletes application; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.delete_application("ONe") }.to raise_error("Missing Business ID")
  end

  # *** :all type solutions

  it "lists solutions" do
    sollist = [{"bizid"=>"XYZxyz",
                "type"=>"product",
                "domain"=>"ABCabc.m2.exosite.io",
                "apiId"=>"ABCabc",
                "sid"=>"ABCabc"},
               {"bizid"=>"XYZxyz",
                "type"=>"application",
                "domain"=>"XYZxyz.apps.exosite.io",
                "apiId"=>"DEFdef",
                "sid"=>"DEFdef"}]
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      to_return(body: sollist)

    ret = @acc.solutions
    expect(ret).to eq(sollist)
  end

  it "lists solutions; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect(@acc).to receive(:debug).with("Getting all solutions of type all")
    expect { @acc.solutions }.to raise_error("Missing Business ID")
  end

  it "creates solution" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      with(:body => {:label=>'one', :type=>'product'}).
      to_return(body: "")

    ret = @acc.new_solution("one")
    expect(ret).to eq({})
  end

  it "creates solution; with upper case" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      with(:body => {:label=>'ONe', :type=>'product'}).
      to_return(body: "")

    expect { @acc.new_solution("ONe") }.to_not raise_error
  end

  it "creates solution; with numbers and dashes" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/").
      with(:body => {:label=>'ONe-8796-gkl', :type=>'product'}).
      to_return(body: "")

    # 2017-05-26: Dashes forbidden! MUR-1994
    #expect { @acc.new_solution("ONe-8796-gkl") }.to_not raise_error
    expect { @acc.new_solution("ONe-8796-gkl") }.to raise_error("Solution name must contain only letters and/or numbers")
  end

  it "creates solution; that is too long" do
    expect { @acc.new_solution("o"*70) }.to raise_error("Solution name must contain only letters and/or numbers")
  end

  it "creates solution; with underscore" do
    expect { @acc.new_solution("one_two") }.to raise_error("Solution name must contain only letters and/or numbers")
  end

  it "creates solution; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.new_solution("one") }.to raise_error("Missing Business ID")
  end

  it "deletes solution" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/one").
      to_return(body: "")

    ret = @acc.delete_solution("one")
    expect(ret).to eq({})
  end

  it "deletes solution; without biz.id" do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @acc.delete_solution("one") }.to raise_error("Missing Business ID")
  end

end

#  vim: set ai et sw=2 ts=2 :
