require 'MrMurano/version'
require 'MrMurano/Solution-Endpoint'
require 'tempfile'

RSpec.describe MrMurano::Endpoint do
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['solution.id'] = 'XYZ'

    @srv = MrMurano::Endpoint.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @srv.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/")
  end

  context "lists" do
    it "same content_type" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"application/json",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"application/json",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id}\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

    it "missing headers" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"application/json",
               :script=>"response.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"application/json",
       :script=> "response.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

    it "not default content_type" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"text/csv",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"image/png",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id} image/png\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

    it "mismatched content_type header" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"text/csv",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"image/png",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id}\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

  end


  context "fetches" do
    it "fetches" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"application/json",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq(body[:script])
    end

    it "missing headers" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"application/json",
              :script=>"response.message = \"HI\"\n",
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq("--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n")
    end

    it "not default content_type" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"text/csv",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq(body[:script])
    end

    it "missing content_type header" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"text/csv",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq("--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n")
    end

    it "mismatched content_type header" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"text/csv",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar image/png\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq("--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n")
    end
  end

  it "removes" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @srv.remove('9K0')
    expect(ret).to eq({})
  end

  it "uploads over old version" do
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
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
                                   :method=>"websocket",
                                   :path=>"/api/v1/bar",
                                   :content_type=>"application/json",
      }, true)
      expect(ret)
    end
  end

  it "uploads when nothing is there" do
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/9K0").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(status: 404)
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint/").
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
                                   :method=>"websocket",
                                   :path=>"/api/v1/bar",
                                   :content_type=>"application/json",
      }, false)
      expect(ret)
    end

  end

  context "compares" do
    before(:example) do
      @iA = {:id=>"9K0",
             :method=>"websocket",
             :path=>"/api/v1/bar",
             :content_type=>"application/json",
             :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
             }
      @iB = {:id=>"9K0",
             :method=>"websocket",
             :path=>"/api/v1/bar",
             :content_type=>"application/json",
             :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
             }
    end
    it "both have script" do
      ret = @srv.docmp(@iA, @iB)
      expect(ret).to eq(false)
    end

    it "iA is a local file" do
      Tempfile.open('foo') do |tio|
        tio << @iA[:script]
        tio.close
        iA = @iA.reject{|k,v| k == :script}.merge({
          :local_path => Pathname.new(tio.path)
        })
        ret = @srv.docmp(iA, @iB)
        expect(ret).to eq(false)

        iB = @iB.dup
        iB[:script] = "BOB"
        ret = @srv.docmp(iA, iB)
        expect(ret).to eq(true)
      end
    end

    it "iB is a local file" do
      Tempfile.open('foo') do |tio|
        tio << @iB[:script]
        tio.close
        iB = @iB.reject{|k,v| k == :script}.merge({
          :local_path => Pathname.new(tio.path)
        })
        ret = @srv.docmp(@iA, iB)
        expect(ret).to eq(false)

        iA = @iB.dup
        iA[:script] = "BOB"
        ret = @srv.docmp(iA, iB)
        expect(ret).to eq(true)
      end
    end
  end

  # TODO: status tests

end
#  vim: set ai et sw=2 ts=2 :
