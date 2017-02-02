require 'MrMurano/version'
require 'MrMurano/Solution-Cors'
require 'tempfile'
require 'yaml'
require '_workspace'

RSpec.describe MrMurano::Cors do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['solution.id'] = 'XYZ'

    @srv = MrMurano::Cors.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @srv.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors/")
  end

  context "when server gives string" do
    it "lists" do
      cors = {:origin=>true,
              :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
              :headers=>["Content-Type","Cookie","Authorization"],
              :credentials=>true}
      body = {:cors=>cors.to_json}
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq([cors.merge({:id=>'cors'})])
    end

    context "fetches" do
      it "as a hash" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = {:cors=>cors.to_json}
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = @srv.fetch()
        expect(ret).to eq(cors)
      end
      it "as a block" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = {:cors=>cors.to_json}
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = ''
        loops = 0
        @srv.fetch() do |chunk|
          loops += 1
          ret << chunk
          expect(loops).to be <= 1
        end
        expect(ret).to eq(Hash.transform_keys_to_strings(cors).to_yaml)
      end
    end
  end

  context "when server gives object" do
    it "lists" do
      cors = {:origin=>true,
              :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
              :headers=>["Content-Type","Cookie","Authorization"],
              :credentials=>true}
      body = cors
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq([cors.merge({:id=>'cors'})])
    end

    context "fetches" do
      it "as a hash" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = cors
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = @srv.fetch()
        expect(ret).to eq(cors)
      end
      it "as a block" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = cors
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = ''
        loops = 0
        @srv.fetch() do |chunk|
          loops += 1
          ret << chunk
          expect(loops).to be <= 1
        end
        expect(ret).to eq(Hash.transform_keys_to_strings(cors).to_yaml)
      end
    end
  end

  it "remove is a nop" do
    ret = @srv.remove('9K0')
    expect(ret).to eq(nil)
  end

  it "uploads over old version" do
    cors = {:origin=>true,
            :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
            :headers=>["Content-Type","Cookie","Authorization"],
            :credentials=>true}
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
      with(:body=>cors.to_json,
        :headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @srv.upload(nil, cors)
    expect(ret)
  end

  context "finding cors.yaml" do
    it "return empty if missing" do
      allow(@srv).to receive(:warning)
      ret = @srv.localitems('cors.yaml')
      expect(ret).to eq([])
    end

    it "return empty if not a file" do
      Dir.mktmpdir do |td|
        tp = File.join(td, 'cors.yaml')
        Dir.mkdir( tp ) # not a file
        allow(@srv).to receive(:warning)
        ret = @srv.localitems(tp)
        expect(ret).to eq([])
      end
    end

    it "return contents" do
      cors = {:origin=>true,
              :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
              :headers=>["Content-Type","Cookie","Authorization"],
              :credentials=>true}

      Tempfile.open('cors.yaml') do |tio|
        tio << Hash.transform_keys_to_strings(cors).to_yaml
        tio.close

        ret = @srv.localitems(tio.path)
        expect(ret).to eq([cors.merge({:id=>'cors', :local_path=>Pathname.new(tio.path)})])
      end
    end

  end

  it "removelocal is a nop" do
    ret = @srv.removelocal('a/path/', {:id=>'cors'})
    expect(ret).to eq(nil)
  end

  it "tolocalpath is into" do
    ret = @srv.tolocalpath('a/path/', {:id=>'cors'})
    expect(ret).to eq('a/path/')
  end

  context "compares" do
    before(:example) do
      @iA = {:origin=>true,
             :methods=>['HEAD','GET'],
             :headers=>['Content-Type'],
             }
      @iB = {:origin=>true,
             :methods=>['HEAD','GET'],
             :headers=>['Content-Type'],
             }
    end
    it "equal" do
      ret = @srv.docmp(@iA,@iB)
      expect(ret).to eq(false)
    end
    it "different" do
      ret = @srv.docmp(@iA,@iB.merge({:foo=>:bar}))
      expect(ret).to eq(true)
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
