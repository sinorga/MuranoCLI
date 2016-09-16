require 'MrMurano/version'
require 'MrMurano/verbosing'
require 'MrMurano/http'
require 'MrMurano/Product'
require 'MrMurano/Config'

RSpec.describe MrMurano::ProductContent, "#product_content" do
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

  it "creates an item" do
    stub_request(:post, @urlroot + "/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/x-www-form-urlencoded'}).
      with(body: {'id'=>'testFor', 'meta'=> 'some meta'}).
      to_return(status: 205)

    ret = @prd.create("testFor", "some meta")
    expect(ret).to eq({})
  end

  it "removes an item" do
    stub_request(:post, @urlroot + "/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/x-www-form-urlencoded'}).
      with(body: {'id'=>'testFor', 'delete'=>'true'}).
      to_return(status: 205)

    ret = @prd.remove("testFor")
    expect(ret).to eq({})
  end

  it "gets info for content" do
    stub_request(:get, @urlroot + "/testFor").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "text/plain,42,123456789,test meta,false")

    ret = @prd.info("testFor")
    expect(ret).to eq([['text/plain','42','123456789','test meta','false']])
  end

  it "removes content" do
    stub_request(:delete, @urlroot + "/testFor").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(status: 205)

    ret = @prd.remove_content("testFor")
    expect(ret).to eq({})
  end

  it "uploads content data" do
    size = FileTest.size('spec/lightbulb.yaml')
    stub_request(:post, @urlroot + "/testFor").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'text/yaml',
                      'Content-Length' => size
    }).
      to_return(status: 205)

    ret = @prd.upload('testFor', 'spec/lightbulb.yaml')
    expect(ret).to eq({})
  end

  it "downloads content" do
    stub_request(:get, @urlroot + "/testFor?download=true").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "short and sweet")

    data = ""
    @prd.download('testFor') {|chunk| data << chunk}
    expect(data).to eq("short and sweet")
  end

end

#  vim: set ai et sw=2 ts=2 :
