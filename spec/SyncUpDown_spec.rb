require 'MrMurano/version'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require 'MrMurano/SyncUpDown'
require '_workspace'

class TSUD
  include MrMurano::Verbose
  include MrMurano::SyncUpDown
  def initialize
    @itemkey = :name
    @locationbase = $cfg['location.base']
    @location = 'tsud'
  end
  def fetch(id)
  end
end
RSpec.describe MrMurano::SyncUpDown do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['solution.id'] = 'XYZ'
  end

  context "status" do
    it "warns with missing directory" do
      t = TSUD.new
      expect(t).to receive(:warning).once.with(/Skipping missing location.*/)
      ret = t.status
      expect(ret).to eq({:toadd=>[], :todel=>[], :tomod=>[], :unchg=>[]})
    end

    it "finds nothing in empty directory" do
      FileUtils.mkpath(@projectDir + '/tsud')
      t = TSUD.new
      ret = t.status
      expect(ret).to eq({:toadd=>[], :todel=>[], :tomod=>[], :unchg=>[]})
    end

    it "finds things there but not here" do
      FileUtils.mkpath(@projectDir + '/tsud')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>1},{:name=>2},{:name=>3}
      ])
      ret = t.status
      expect(ret).to eq({
        :toadd=>[],
        :todel=>[{:name=>1, :synckey=>1}, {:name=>2, :synckey=>2}, {:name=>3, :synckey=>3}],
        :tomod=>[],
        :unchg=>[]})
    end

    it "finds things there but not here; asdown" do
      FileUtils.mkpath(@projectDir + '/tsud')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>1},{:name=>2},{:name=>3}
      ])
      ret = t.status({:asdown=>true})
      expect(ret).to eq({
        :todel=>[],
        :toadd=>[{:name=>1, :synckey=>1}, {:name=>2, :synckey=>2}, {:name=>3, :synckey=>3}],
        :tomod=>[],
        :unchg=>[]})
    end

    it "finds things here but not there" do
      FileUtils.mkpath(@projectDir + '/tsud')
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:toRemoteItem).and_return(
        {:name=>'one.lua'},{:name=>'two.lua'}
      )
      ret = t.status
      expect(ret).to match({
        :toadd=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>an_instance_of(Pathname)},
          {:name=>'two.lua', :synckey=>'two.lua',
           :local_path=>an_instance_of(Pathname)},
        ],
        :todel=>[],
        :tomod=>[],
        :unchg=>[]})
    end

    it "finds things here and there" do
      FileUtils.mkpath(@projectDir + '/tsud')
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>'one.lua'},{:name=>'two.lua'}
      ])
      expect(t).to receive(:toRemoteItem).and_return(
        {:name=>'one.lua'},{:name=>'two.lua'}
      )
      ret = t.status
      expect(ret).to match({
        :tomod=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>an_instance_of(Pathname)},
          {:name=>'two.lua', :synckey=>'two.lua',
           :local_path=>an_instance_of(Pathname)},
        ],
        :todel=>[],
        :toadd=>[],
        :unchg=>[]})
    end
    it "finds things here and there; but they're the same" do
      FileUtils.mkpath(@projectDir + '/tsud')
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>'one.lua'},{:name=>'two.lua'}
      ])
      expect(t).to receive(:toRemoteItem).and_return(
        {:name=>'one.lua'},{:name=>'two.lua'}
      )
      expect(t).to receive(:docmp).twice.and_return(false)
      ret = t.status
      expect(ret).to match({
        :unchg=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>an_instance_of(Pathname)},
          {:name=>'two.lua', :synckey=>'two.lua',
           :local_path=>an_instance_of(Pathname)},
        ],
        :todel=>[],
        :toadd=>[],
        :tomod=>[]})
    end

    it "calls diff" do
      FileUtils.mkpath(@projectDir + '/tsud')
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>'one.lua'}
      ])
      expect(t).to receive(:toRemoteItem).and_return(
        {:name=>'one.lua'}
      )
      expect(t).to receive(:dodiff).once.and_return("diffed output")
      ret = t.status({:diff=>true})
      expect(ret).to match({
        :tomod=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>an_instance_of(Pathname),
           :diff=>"diffed output"},
        ],
        :todel=>[],
        :toadd=>[],
        :unchg=>[]})
    end
  end

  context "localitems" do
    before(:example) do
      FileUtils.mkpath('tsud')
      FileUtils.touch('tsud/one.lua')
      FileUtils.touch('tsud/two.lua')
      @t = TSUD.new
    end
    it "finds local items" do
      expect(@t).to receive(:toRemoteItem).and_return(
        {:name=>'one.lua'},{:name=>'two.lua'}
      )
      ret = @t.localitems(Pathname.new(@projectDir + '/tsud').realpath)
      expect(ret).to match([
        {:name=>'one.lua',
         :local_path=>an_instance_of(Pathname)},
      {:name=>'two.lua',
       :local_path=>an_instance_of(Pathname)},
      ])
    end

    it "takes an array from toRemoteItem" do
      expect(@t).to receive(:toRemoteItem).and_return(
        [{:name=>'one:1'},{:name=>'one:2'}],
        [{:name=>'two:1'},{:name=>'two:2'}]
        )
      ret = @t.localitems(Pathname.new(@projectDir + '/tsud').realpath)
      expect(ret).to match([
        {:name=>'one:1',
         :local_path=>an_instance_of(Pathname)},
        {:name=>'one:2',
         :local_path=>an_instance_of(Pathname)},
        {:name=>'two:1',
         :local_path=>an_instance_of(Pathname)},
        {:name=>'two:2',
         :local_path=>an_instance_of(Pathname)},
      ])
    end
  end

  context "download" do
    it "defaults to :id if @itemkey missing" do
      FileUtils.mkpath(@projectDir + '/tsud')
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      lp = Pathname.new(@projectDir + '/tsud/one.lua').realpath
      t = TSUD.new
      expect(t).to receive(:fetch).once.with(1).and_yield("foo")
      t.download(lp, {:id=>1})
    end
  end

  context "doing diffs" do
    before(:example) do
      FileUtils.mkpath(@projectDir + '/tsud')
      @t = TSUD.new
      @scpt = Pathname.new(@projectDir + '/tsud/one.lua')
      @scpt.open('w'){|io| io << %{-- fake lua\nreturn 0\n}}
      @scpt = @scpt.realpath
    end

    it "nothing when same." do
      expect(@t).to receive(:fetch).and_yield(%{-- fake lua\nreturn 0\n})
      ret = @t.dodiff({:name=>'one.lua', :local_path=>@scpt})
      if Gem.win_platform? then
        expect(ret).to match(/FC: no differences encountered/)
      else
        expect(ret).to eq('')
      end
    end

    it "something when different." do
      expect(@t).to receive(:fetch).and_yield(%{-- fake lua\nreturn 2\n})
      ret = @t.dodiff({:name=>'one.lua', :local_path=>@scpt})
      expect(ret).not_to eq('')
    end

    it "uses script in item" do
      script = %{-- fake lua\nreturn 2\n}
      expect(@t).to receive(:fetch).and_yield(script)
      ret = @t.dodiff({:name=>'one.lua', :local_path=>@scpt, :script=>script})
      if Gem.win_platform? then
        expect(ret).to match(/FC: no differences encountered/)
      else
        expect(ret).to eq('')
      end
    end
  end

  context "syncup" do
    before(:example) do
      FileUtils.mkpath(@projectDir + '/tsud')
      @t = TSUD.new
    end

    it "removes" do
      expect(@t).to receive(:list).once.and_return([
        {:name=>1},{:name=>2},{:name=>3}
      ])
      expect(@t).to receive(:remove).exactly(3).times
      @t.syncup({:delete=>true})
    end

    it "creates" do
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/tsud/two.lua')

      expect(@t).to receive(:upload).twice.with(kind_of(Pathname), kind_of(Hash), false)
      @t.syncup({:create=>true})
    end

    it "updates" do
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/tsud/two.lua')
      expect(@t).to receive(:list).once.and_return([
        {:name=>'one.lua'},{:name=>'two.lua'}
      ])

      expect(@t).to receive(:upload).twice.with(kind_of(Pathname), kind_of(Hash), true)
      expect(@t).to receive(:toRemoteItem).and_return(
        {:name=>'one.lua'},{:name=>'two.lua'}
      )
      @t.syncup({:update=>true})
    end
  end

  context "syncdown" do
    before(:example) do
      FileUtils.mkpath(@projectDir + '/tsud')
      @t = TSUD.new
    end

    it "removes" do
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/tsud/two.lua')

      @t.syncdown({:delete=>true})
      expect(FileTest.exist?(@projectDir + '/tsud/one.lua')).to be false
      expect(FileTest.exist?(@projectDir + '/tsud/two.lua')).to be false
    end

    it "creates" do
      expect(@t).to receive(:list).once.and_return([
        {:name=>'one.lua'},{:name=>'two.lua'}
      ])

      expect(@t).to receive(:fetch).twice.and_yield("--foo\n")
      @t.syncdown({:create=>true})
      expect(FileTest.exist?(@projectDir + '/tsud/one.lua')).to be true
      expect(FileTest.exist?(@projectDir + '/tsud/two.lua')).to be true
    end

    it "updates" do
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/tsud/two.lua')
      expect(@t).to receive(:list).once.and_return([
        {:name=>'one.lua'},{:name=>'two.lua'}
      ])

      expect(@t).to receive(:fetch).twice.and_yield("--foo\n")
      expect(@t).to receive(:toRemoteItem).and_return(
        {:name=>'one.lua'},{:name=>'two.lua'}
      )
      @t.syncdown({:update=>true})
      expect(FileTest.exist?(@projectDir + '/tsud/one.lua')).to be true
      expect(FileTest.exist?(@projectDir + '/tsud/two.lua')).to be true
    end
  end

  context "bundles" do
    before(:example) do
      FileUtils.mkpath(@projectDir + '/tsud')
      FileUtils.mkpath(@projectDir + '/bundles/mybun/tsud')
      @t = TSUD.new
    end

    it "finds items in bundles." do
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      FileUtils.touch(@projectDir + '/bundles/mybun/tsud/two.lua')

      expect(@t).to receive(:toRemoteItem).and_return(
        {:name=>'two.lua'},{:name=>'one.lua'}
      )
      ret = @t.locallist
      expect(ret).to match([
        {:name=>'two.lua',
         :bundled=>true,
         :local_path=>an_instance_of(Pathname)},
        {:name=>'one.lua',
         :local_path=>an_instance_of(Pathname)},
      ])
    end

    it "Doesn't download a bundled item" do
      FileUtils.touch(@projectDir + '/tsud/one.lua')
      lp = Pathname.new(@projectDir + '/tsud/one.lua').realpath

      expect(@t).to receive(:warning).once.with(/Not downloading into bundled item.*/)

      @t.download(lp, {:bundled=>true, :name=>'one.lua'})
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
