require 'MrMurano/version'
require 'MrMurano/Content'
require '_workspace'

RSpec.describe MrMurano::Content::Base do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['project.id'] = 'XYZ'

    @ct = MrMurano::Content::Base.new
    allow(@ct).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @ct.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/")
  end

  it "lists" do
    body = [{
      :type=> "binary/octet-stream",
      :tags=> { :name=> "TODO.taskpaper" },
      :size=> 5622,
      :mtime=> "2017-02-10T17:43:45.000Z",
      :id=> "8076e5d091844814d7f5cd97a1a730aa"
    }]

    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/list").
      to_return(:body => body.to_json)

    ret = @ct.list
    expect(ret).to eq(body)
  end

  it "clears all" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/clear")
    ret = @ct.clear_all
    expect(ret).to eq({})
  end

  it "fetches info for one" do
    body = {
      :type=> "binary/octet-stream",
      :tags=> { :name=> "TODO.taskpaper" },
      :size=> 5622,
      :mtime=> "2017-02-10T17:43:45.000Z",
      :id=> "8076e5d091844814d7f5cd97a1a730aa"
    }

    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/info?name=TODO.taskpaper").
      to_return(:body => body.to_json)

    ret = @ct.fetch('TODO.taskpaper')
    expect(ret).to eq(body)
  end

  it "removes one" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/delete?name=TODO.taskpaper")

    ret = @ct.remove('TODO.taskpaper')
    expect(ret).to eq({})
  end

  context "uploads" do
  end
  context "downloads" do
    it "something to stdout" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ",
        :method=>"GET",
        :id=>"8076e5d091844814d7f5cd97a1a730aa"
      }

      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/download?name=TODO.taskpaper").
        to_return(:body => body.to_json)

      stub_request(:get , "https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ").
        to_return(:body => "FOOOOOOOOOOOO")

      saved = $stdout
      $stdout = StringIO.new

      @ct.download('TODO.taskpaper')
      expect($stdout.string).to eq("FOOOOOOOOOOOO")
      $stdout = saved
    end

    it "something to block" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ",
        :method=>"GET",
        :id=>"8076e5d091844814d7f5cd97a1a730aa"
      }

      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/download?name=TODO.taskpaper").
        to_return(:body => body.to_json)

      stub_request(:get , "https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ").
        to_return(:body => "FOOOOOOOOOOOO")

      expect{|b| @ct.download('TODO.taskpaper', &b) }.to yield_with_args("FOOOOOOOOOOOO")
    end

    it "something that isn't there" do
      # bizapi/content/download always returns GET instructions? yes.
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ",
        :method=>"GET",
        :id=>"8076e5d091844814d7f5cd97a1a730aa"
      }

      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/download?name=Notthere").
        to_return(:body => body.to_json)

      resp = %{
        <?xml version="1.0" encoding="UTF-8"?>
        <Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message><Key>XXX/ZZZ</Key><RequestId>12</RequestId><HostId>=</HostId></Error>
      }
      stub_request(:get , "https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ").
        to_return(:status=>404, :body => resp)

      saved = $stderr
      $stderr = StringIO.new

      ret = @ct.download('Notthere')
      expect(ret).to match(Net::HTTPNotFound)
      expect($stderr.string).to eq("\e[31mRequest Failed: 404: " + resp + "\e[0m\n")
      $stderr = saved
    end

    it "something to block with --curl" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ",
        :method=>"GET",
        :id=>"8076e5d091844814d7f5cd97a1a730aa"
      }

      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/download?name=TODO.taskpaper").
        to_return(:body => body.to_json)

      stub_request(:get , "https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ").
        to_return(:body => "FOOOOOOOOOOOO")

      saved = $stdout
      $stdout = StringIO.new

      $cfg['tool.curldebug'] = true
      @ct.download('TODO.taskpaper')
      expect($stdout.string).to eq(%{curl -s  -H 'Authorization: token TTTTTTTTTT' -H 'User-Agent: MrMurano/2.0.0.pre' -H 'Content-Type: application/json' -X GET 'https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/download?name=TODO.taskpaper'\ncurl -s -H 'User-Agent: MrMurano/2.0.0.pre' -X GET 'https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ'\nFOOOOOOOOOOOO})
      $stdout = saved
    end

    it "something to block with --dry" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging/XXX/ZZZ",
        :method=>"GET",
        :id=>"8076e5d091844814d7f5cd97a1a730aa"
      }

      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/download?name=TODO.taskpaper").
        to_return(:body => body.to_json)

      $cfg['tool.dry'] = true
      @ct.download('TODO.taskpaper')

    end
  end

end
#  vim: set ai et sw=2 ts=2 :
