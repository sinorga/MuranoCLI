require 'MrMurano/version'
require 'MrMurano/Solution-Services'
require 'tempfile'

RSpec.describe MrMurano::EventHandler do
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['solution.id'] = 'XYZ'

    @srv = MrMurano::EventHandler.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @srv.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler/")
  end

  it "lists" do
    body = {:items=>[{:id=>"9K0",
             :name=>"debug",
             :alias=>"XYZ_debug",
             :solution_id=>"XYZ",
             :service=>"device",
             :event=>"datapoint",
             :created_at=>"2016-07-07T19:16:19.479Z",
             :updated_at=>"2016-09-12T13:26:55.868Z"}],
            :total=>1}
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: body.to_json)

    ret = @srv.list()
    expect(ret).to eq(body[:items])
  end

  it "fetches, with header" do
    body = {:id=>"9K0",
             :name=>"debug",
             :alias=>"XYZ_debug",
             :solution_id=>"XYZ",
             :service=>"device",
             :event=>"datapoint",
             :created_at=>"2016-07-07T19:16:19.479Z",
             :updated_at=>"2016-09-12T13:26:55.868Z",
             :script=>%{--#EVENT device datapoint
             -- lua code is here
    function foo(bar)
      return bar + 1
    end
    }
    }
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler/9K0").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: body.to_json)

    ret = @srv.fetch('9K0')
    expect(ret).to eq(body[:script])
  end

  it "fetches, without header" do
    body = {:id=>"9K0",
             :name=>"debug",
             :alias=>"XYZ_debug",
             :solution_id=>"XYZ",
             :service=>"device",
             :event=>"datapoint",
             :created_at=>"2016-07-07T19:16:19.479Z",
             :updated_at=>"2016-09-12T13:26:55.868Z",
             :script=>%{-- lua code is here
function foo(bar)
  return bar + 1
end
}
    }
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler/9K0").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: body.to_json)

    ret = @srv.fetch('9K0')
    expect(ret).to eq(%{--#EVENT device datapoint
-- lua code is here
function foo(bar)
  return bar + 1
end
})
  end

  it "removes" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler/9K0").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @srv.remove('9K0')
    expect(ret).to eq({})
  end

  it "uploads over old version" do
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler/XYZ_data_datapoint").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    Tempfile.open('foo') do |tio|
      tio << %{-- lua code is here
    function foo(bar)
      return bar + 1
    end
      }
      tio.close

      ret = @srv.upload(tio.path, {:id=>"9K0",
                                   :service=>'data',
                                   :event=>'datapoint',
                                   :solution_id=>"XYZ",
      })
      expect(ret)
    end
  end

  it "uploads when nothing is there" do
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler/XYZ_device_datapoint").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(status: 404)
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/eventhandler/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    Tempfile.open('foo') do |tio|
      tio << %{-- lua code is here
    function foo(bar)
      return bar + 1
    end
      }
      tio.close

      ret = @srv.upload(tio.path, {:id=>"9K0",
                                   :solution_id=>"XYZ",
                                   :service=>"device",
                                   :event=>"datapoint",
      })
      expect(ret)
    end

  end

  context "compares" do
    before(:example) do
      @iA = {:id=>"9K0",
            :name=>"debug",
            :alias=>"XYZ_debug",
            :solution_id=>"XYZ",
             :service=>"device",
             :event=>"datapoint",
            :created_at=>"2016-07-07T19:16:19.479Z",
            :updated_at=>"2016-09-12T13:26:55.868Z"}
      @iB = {:id=>"9K0",
            :name=>"debug",
            :alias=>"XYZ_debug",
            :solution_id=>"XYZ",
             :service=>"device",
             :event=>"datapoint",
            :created_at=>"2016-07-07T19:16:19.479Z",
            :updated_at=>"2016-09-12T13:26:55.868Z"}
    end
    it "both have updated_at" do
      ret = @srv.docmp(@iA, @iB)
      expect(ret).to eq(false)
    end

    it "iA is a local file" do
      Tempfile.open('foo') do |tio|
        tio << "something"
        tio.close
        iA = @iA.reject{|k,v| k == :updated_at}.merge({
          :local_path => Pathname.new(tio.path)
        })
        ret = @srv.docmp(iA, @iB)
        expect(ret).to eq(true)

        iB = @iB.merge({:updated_at=>Pathname.new(tio.path).mtime.getutc})
        ret = @srv.docmp(iA, iB)
        expect(ret).to eq(false)
      end
    end

    it "iB is a local file" do
      Tempfile.open('foo') do |tio|
        tio << "something"
        tio.close
        iB = @iB.reject{|k,v| k == :updated_at}.merge({
          :local_path => Pathname.new(tio.path)
        })
        ret = @srv.docmp(@iA, iB)
        expect(ret).to eq(true)

        iA = @iA.merge({:updated_at=>Pathname.new(tio.path).mtime.getutc})
        ret = @srv.docmp(iA, iB)
        expect(ret).to eq(false)
      end
    end
  end

  # TODO: status tests

end
#  vim: set ai et sw=2 ts=2 :
