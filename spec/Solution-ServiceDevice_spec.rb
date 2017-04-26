require 'MrMurano/version'
require 'MrMurano/Solution-ServiceConfig'
require 'tempfile'
require '_workspace'

RSpec.describe MrMurano::SC_Device do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['project.id'] = 'XYZ'

    @srv = MrMurano::SC_Device.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @srv.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/")
  end

  it "lists triggers; with scid lookup" do
    body = {:items=>[{
      :id =>  "624098f1",
      :name =>  "Device Gateway Service",
      :alias =>  "XYZ_device",
      :solution_id =>  "XYZ",
      :quota =>  {},
      :service =>  "device",
      :status =>  "ready",
      :created_at =>  "2016-07-13T19:24:14.206Z",
      :updated_at =>  "2016-08-01T15:44:11.433Z",
      :deleted_at =>  nil
    }], :total=>1}
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: body.to_json)


    body = {
      :id =>  "624098f1",
      :alias =>  "XYZ_device",
      :name =>  "Device Gateway Service",
      :status =>  "ready",
      :solution_id =>  "XYZ",
      :service =>  "device",
      :parameters =>  {
        :bizid =>  "ABCDEFG",
      },
      :triggers =>  {
        :pid =>  [
          "LMNOP"
        ]
      },
      :quota =>  {},
      :created_at =>  "2016-07-13T19:24:14.206Z",
      :updated_at =>  "2016-08-01T15:44:11.433Z",
      :deleted_at =>  nil
    }
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/624098f1").
      with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
      to_return(:body => body.to_json)

    ret = @srv.showTriggers
    expect(ret).to eq(["LMNOP"])
  end

  it "lists triggers" do
    expect(@srv).to receive(:scid).once.and_return('624098f1')
    body = {
      :id =>  "624098f1",
      :alias =>  "XYZ_device",
      :name =>  "Device Gateway Service",
      :status =>  "ready",
      :solution_id =>  "XYZ",
      :service =>  "device",
      :parameters =>  {
        :bizid =>  "ABCDEFG",
      },
      :triggers =>  {
        :pid =>  [
          "LMNOP"
        ]
      },
      :quota =>  {},
      :created_at =>  "2016-07-13T19:24:14.206Z",
      :updated_at =>  "2016-08-01T15:44:11.433Z",
      :deleted_at =>  nil
    }
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/624098f1").
      with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
      to_return(:body => body.to_json)

    ret = @srv.showTriggers
    expect(ret).to eq(["LMNOP"])
  end

  it "assigns trigger" do
    expect(@srv).to receive(:scid).twice.and_return('624098f1')
    body = {
      :id =>  "624098f1",
      :alias =>  "XYZ_device",
      :name =>  "Device Gateway Service",
      :status =>  "ready",
      :solution_id =>  "XYZ",
      :service =>  "device",
      :parameters =>  {
        :bizid =>  "ABCDEFG",
      },
      :triggers =>  {
        :pid =>  [
          "LMNOP"
        ]
      },
      :quota =>  {},
      :created_at =>  "2016-07-13T19:24:14.206Z",
      :updated_at =>  "2016-08-01T15:44:11.433Z",
      :deleted_at =>  nil
    }
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/624098f1").
      with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
      to_return(:body => body.to_json)

    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/624098f1").
      with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
      to_return(:body => '')

    ret = @srv.assignTriggers('OTTF')
    expect(ret).to eq({})
  end

  it "assigns multiple triggers" do
    expect(@srv).to receive(:scid).twice.and_return('624098f1')
    body = {
      :id =>  "624098f1",
      :alias =>  "XYZ_device",
      :name =>  "Device Gateway Service",
      :status =>  "ready",
      :solution_id =>  "XYZ",
      :service =>  "device",
      :parameters =>  {
        :bizid =>  "ABCDEFG",
      },
      :triggers =>  {
        :pid =>  [
          "LMNOP"
        ]
      },
      :quota =>  {},
      :created_at =>  "2016-07-13T19:24:14.206Z",
      :updated_at =>  "2016-08-01T15:44:11.433Z",
      :deleted_at =>  nil
    }
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/624098f1").
      with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
      to_return(:body => body.to_json)

    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/624098f1").
      with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
      to_return(:body => '')

    ret = @srv.assignTriggers(['OTTF', '1234'])
    expect(ret).to eq({})
  end
end
#  vim: set ai et sw=2 ts=2 :
