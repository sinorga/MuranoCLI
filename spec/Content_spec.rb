require 'fileutils'
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
    before(:example) do
      @tup = Pathname.new(@projectDir) + 'Solutionfile.json'
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/SolutionFiles/basic.json'), @tup.to_path)
    end

    it "uploads file" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging",
        :method=>"POST",
        :inputs=>{
          :"x-amz-meta-name"=>"Solutionfile.json",
          :"x-amz-signature"=>"Bunch of Hex",
          :"x-amz-date"=>"20170214T200752Z",
          :"x-amz-credential"=>"AAA/BBB/us-west-1/s3/aws4_request",
          :"x-amz-algorithm"=>"AWS4-HMAC-SHA256",
          :policy=>"something base64 encoded.",
          :key=>"XXX/ZZZ",
          :acl=>"authenticated-read"
        },
        :id=>"more Hex",
        :field=>"file",
        :enctype=>"multipart/form-data"
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/upload").
        with(:query=>{
          :expires_in=>30,
          :name=>'Solutionfile.json',
          :sha256=>'018d1e072e1e9734cbc804c27121d00a2912fe14bcc11244e3fc20c5b72ab136',
          :type=>'application/json'}).
        to_return(:body => body.to_json)

      stub_request(:post, "https://s3-us-west-1.amazonaws.com/murano-content-service-staging").
        with(:headers=>{"Content-Type"=>%r|\Amultipart/form-data|}) do |request|
          request.body =~ /something base64 encoded/
        end.
        to_return(:status=>200)

      @ct.upload('Solutionfile.json', @tup.to_path)
    end

    it "uploads with tags" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging",
        :method=>"POST",
        :inputs=>{
          :"x-amz-meta-name"=>"Solutionfile.json",
          :"x-amz-signature"=>"Bunch of Hex",
          :"x-amz-date"=>"20170214T200752Z",
          :"x-amz-credential"=>"AAA/BBB/us-west-1/s3/aws4_request",
          :"x-amz-algorithm"=>"AWS4-HMAC-SHA256",
          :policy=>"something base64 encoded.",
          :key=>"XXX/ZZZ",
          :acl=>"authenticated-read"
        },
        :id=>"more Hex",
        :field=>"file",
        :enctype=>"multipart/form-data"
      }
      tags = {:one=>12, :four=>'bob'}
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/upload").
        with(:query=>{
          :expires_in=>30,
          :name=>'Solutionfile.json',
          :sha256=>'018d1e072e1e9734cbc804c27121d00a2912fe14bcc11244e3fc20c5b72ab136',
          :type=>'application/json',
          :tags => tags.to_json}).
        to_return(:body => body.to_json)

      stub_request(:post, "https://s3-us-west-1.amazonaws.com/murano-content-service-staging").
        with(:headers=>{"Content-Type"=>%r|\Amultipart/form-data|}) do |request|
          request.body =~ /something base64 encoded/
        end.
        to_return(:status=>200)

      @ct.upload('Solutionfile.json', @tup.to_path, tags)
    end

    it "uploads fail at S3" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging",
        :method=>"POST",
        :inputs=>{
          :"x-amz-meta-name"=>"Solutionfile.json",
          :"x-amz-signature"=>"Bunch of Hex",
          :"x-amz-date"=>"20170214T200752Z",
          :"x-amz-credential"=>"AAA/BBB/us-west-1/s3/aws4_request",
          :"x-amz-algorithm"=>"AWS4-HMAC-SHA256",
          :policy=>"something base64 encoded.",
          :key=>"XXX/ZZZ",
          :acl=>"authenticated-read"
        },
        :id=>"more Hex",
        :field=>"file",
        :enctype=>"multipart/form-data"
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/upload").
        with(:query=>{
          :expires_in=>30,
          :name=>'Solutionfile.json',
          :sha256=>'018d1e072e1e9734cbc804c27121d00a2912fe14bcc11244e3fc20c5b72ab136',
          :type=>'application/json'}).
        to_return(:body => body.to_json)

      stub_request(:post, "https://s3-us-west-1.amazonaws.com/murano-content-service-staging").
        with(:headers=>{"Content-Type"=>%r|\Amultipart/form-data|}) do |request|
          request.body =~ /something base64 encoded/
        end.
        to_return(:status=>500)

      saved = $stderr
      $stderr = StringIO.new

      @ct.upload('Solutionfile.json', @tup.to_path)
      expect($stderr.string).to eq("\e[31mRequest Failed: 500: nil\e[0m\n")
      $stderr = saved
    end

    it "uploads with --dry" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging",
        :method=>"POST",
        :inputs=>{
          :"x-amz-meta-name"=>"resources.yaml",
          :"x-amz-signature"=>"Bunch of Hex",
          :"x-amz-date"=>"20170214T200752Z",
          :"x-amz-credential"=>"AAA/BBB/us-west-1/s3/aws4_request",
          :"x-amz-algorithm"=>"AWS4-HMAC-SHA256",
          :policy=>"something base64 encoded.",
          :key=>"XXX/ZZZ",
          :acl=>"authenticated-read"
        },
        :id=>"more Hex",
        :field=>"file",
        :enctype=>"multipart/form-data"
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/upload?expires_in=30&name=Solutionfile.json&sha256=018d1e072e1e9734cbc804c27121d00a2912fe14bcc11244e3fc20c5b72ab136&type=application/json").
        to_return(:body => body.to_json)

      $cfg['tool.dry'] = true
      @ct.upload('Solutionfile.json', @tup.to_path)
    end

    it "uploads with --curl" do
      body = {
        :url=>"https://s3-us-west-1.amazonaws.com/murano-content-service-staging",
        :method=>"POST",
        :inputs=>{
          :"x-amz-meta-name"=>"Solutionfile.json",
          :"x-amz-signature"=>"Bunch of Hex",
          :"x-amz-date"=>"20170214T200752Z",
          :"x-amz-credential"=>"AAA/BBB/us-west-1/s3/aws4_request",
          :"x-amz-algorithm"=>"AWS4-HMAC-SHA256",
          :policy=>"something base64 encoded.",
          :key=>"XXX/ZZZ",
          :acl=>"authenticated-read"
        },
        :id=>"more Hex",
        :field=>"file",
        :enctype=>"multipart/form-data"
      }
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/upload").
        with(:query=>{
          :expires_in=>30,
          :name=>'Solutionfile.json',
          :sha256=>'018d1e072e1e9734cbc804c27121d00a2912fe14bcc11244e3fc20c5b72ab136',
          :type=>'application/json'}).
        to_return(:body => body.to_json)

      stub_request(:post, "https://s3-us-west-1.amazonaws.com/murano-content-service-staging").
        with(:headers=>{"Content-Type"=>%r|\Amultipart/form-data|}) do |request|
          request.body =~ /something base64 encoded/
        end.
        to_return(:status=>200)

      saved = $stdout
      $stdout = StringIO.new

      $cfg['tool.curldebug'] = true
      @ct.upload('Solutionfile.json', @tup.to_path)
      expect($stdout.string).to start_with(%{curl -s  -H 'Authorization: token TTTTTTTTTT' -H 'User-Agent: MrMurano/2.0.0.pre' -H 'Content-Type: application/json' -X GET 'https://bizapi.hosted.exosite.io/api:1/service/XYZ/content/upload?sha256=018d1e072e1e9734cbc804c27121d00a2912fe14bcc11244e3fc20c5b72ab136&expires_in=30&type=application%2Fjson&name=Solutionfile.json'\ncurl -s -H 'User-Agent: MrMurano/2.0.0.pre' -X POST 'https://s3-us-west-1.amazonaws.com/murano-content-service-staging' -F 'x-amz-meta-name=Solutionfile.json' -F 'x-amz-signature=Bunch of Hex' -F 'x-amz-date=20170214T200752Z' -F 'x-amz-credential=AAA/BBB/us-west-1/s3/aws4_request' -F 'x-amz-algorithm=AWS4-HMAC-SHA256' -F 'policy=something base64 encoded.' -F 'key=XXX/ZZZ' -F 'acl=authenticated-read' -F file=@}).
        and end_with(%{/home/work/project/Solutionfile.json\n})
      $stdout = saved
    end
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