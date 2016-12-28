require 'MrMurano/version'
require 'MrMurano/Config'
require '_workspace'
require 'tempfile'
require 'erb'

RSpec.describe MrMurano::Config do

  context "Basics " do
    include_context "WORKSPACE"
    it "Sets defaults" do
      cfg = MrMurano::Config.new
      cfg.load
      # Don't check for all of them, just a few.
      expect(cfg['files.default_page']).to eq('index.html')
      expect(cfg.get('files.default_page', :defaults)).to eq('index.html')
      expect(cfg['tool.debug']).to eq(false)
      expect(cfg.get('tool.debug', :defaults)).to eq(false)
    end

    it "Sets internal values" do
      cfg = MrMurano::Config.new
      cfg.load

      cfg['bob.test'] = 'twelve'

      expect(cfg['bob.test']).to eq('twelve')
      expect(cfg.get('bob.test', :internal)).to eq('twelve')
    end

    it "Sets tool values" do
      cfg = MrMurano::Config.new
      cfg.load

      cfg['test'] = 'twelve'

      expect(cfg['tool.test']).to eq('twelve')
      expect(cfg.get('tool.test', :internal)).to eq('twelve')
    end

    it "Sets project values" do # This should write
      cfg = MrMurano::Config.new
      cfg.load

      cfg.set('bob.test', 'twelve', :project)

      expect(cfg['bob.test']).to eq('twelve')
      expect(cfg.get('bob.test', :project)).to eq('twelve')

      expect(FileTest.exist?(@projectDir + '.mrmuranorc'))

      #reload
      cfg = MrMurano::Config.new
      cfg.load
      expect(cfg.get('bob.test', :project)).to eq('twelve')
    end

    it "Sets a user value" do
      cfg = MrMurano::Config.new
      cfg.load

      cfg.set('bob.test', 'twelve', :user)

      expect(cfg['bob.test']).to eq('twelve')
      expect(cfg.get('bob.test', :user)).to eq('twelve')

      expect(FileTest.exist?(ENV['HOME'] + '.mrmuranorc'))

      #reload
      cfg = MrMurano::Config.new
      cfg.load
      expect(cfg.get('bob.test', :user)).to eq('twelve')
    end

    it "loads from a specific file" do
      File.open(@projectDir + '/foo.cfg', 'w') do |io|
        io << %{[test]
            bob = test
        }.gsub(/^\s\+/,'')
      end

      cfg = MrMurano::Config.new
      cfg.load
      cfg.load_specific(@projectDir + '/foo.cfg')

      expect(cfg['test.bob']).to eq('test')
    end

    it "returns a path to a file in project mrmurano dir" do
      cfg = MrMurano::Config.new
      cfg.load
      path = cfg.file_at('testfile').realdirpath
      want = Pathname.new(@projectDir + '/.mrmurano/testfile').realdirpath

      expect(path).to eq(want)
    end

    it "returns a path to a file in user mrmurano dir" do
      cfg = MrMurano::Config.new
      cfg.load
      path = cfg.file_at('testfile', :user).realdirpath
      want = Pathname.new(Dir.home + '/.mrmurano/testfile').realdirpath

      expect(path).to eq(want)
    end

    context "ENV['MR_CONFIGFILE']" do
      it "loads file in env" do
        ENV['MR_CONFIGFILE'] = @tmpdir + '/home/test.config'
        File.open(@tmpdir + '/home/test.config', 'w') do |io|
          io << %{[test]
            bob = test
          }.gsub(/^\s\+/,'')
        end

        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg['test.bob']).to eq('test')
      end

      it "will create file at env" do
        ENV['MR_CONFIGFILE'] = @tmpdir + '/home/testcreate.config'
        cfg = MrMurano::Config.new
        cfg.load
        cfg.set('coffee.hot', 'yes', :env)

        expect(FileTest.exist?(ENV['MR_CONFIGFILE']))

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg['coffee.hot']).to eq('yes')
        expect(cfg.get('coffee.hot', :env)).to eq('yes')
      end
    end

    it "dumps" do
      cfg = MrMurano::Config.new
      cfg.load
      ret = cfg.dump

      rawwant = IO.read(File.join(@testdir.to_path, 'spec','fixtures','dumped_config'))
      template = ERB.new(rawwant)
      want = template.result(binding)

      expect(ret).to eq(want)
    end
  end

  context "Can find the project directory by .mrmuranorc" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @projectDir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.touch(@projectDir + '/.mrmuranorc')

      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "when in project directory" do
      Dir.chdir(@projectDir) do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when in sub directory" do
      Dir.chdir(@projectDir + '/some/where') do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end
  end

  context "Can find the project directory by .mrmurano/" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @projectDir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.mkpath(@projectDir + '/.mrmurano')

      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "when in project directory" do
      Dir.chdir(@projectDir) do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when in sub directory" do
      Dir.chdir(@projectDir + '/some/where') do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end
  end

  context "Can find the project directory by .git/" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @projectDir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.mkpath(@projectDir + '/.git')

      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "when in project directory" do
      Dir.chdir(@projectDir) do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when in sub directory" do
      Dir.chdir(@projectDir + '/some/where') do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end
  end

  context "Can find the project directory by .mrmuranorc but not sub .git/" do
    #
    # /home/work/project/
    # /home/work/project/.mrmuranorc
    # /home/work/project/some/.git
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @projectDir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.touch(@projectDir + '/.mrmuranorc')
      FileUtils.mkpath(@projectDir + '/some/.git')

      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "when in project directory" do
      Dir.chdir(@projectDir) do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when in sub directory" do
      Dir.chdir(@projectDir + '/some/where') do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end
  end

  context "Can find the project directory by .mrmuranorc but not parent .git/" do
    # /home/work/project/
    # /home/work/project/.git
    # /home/work/project/some/.mrmuranorc
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @projectDir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.touch(@projectDir + '/some/.mrmuranorc')
      FileUtils.mkpath(@projectDir + '/.git')

      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "when in project directory" do
      Dir.chdir(@projectDir) do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir).realdirpath
        # This will correctly assume that this project dir with .git is the
        # location.base
        expect(locbase).to eq(wkd)
      end
    end

    it "when in sub directory" do
      Dir.chdir(@projectDir + '/some/where') do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@projectDir+'/some').realdirpath
        expect(locbase).to eq(wkd)
      end
    end
  end

  context "When pwd is $HOME:" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      @projectDir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@projectDir)
      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "Sets a user value" do
      Dir.chdir(ENV['HOME']) do
        cfg = MrMurano::Config.new
        cfg.load

        cfg.set('bob.test', 'twelve', :user)

        expect(cfg['bob.test']).to eq('twelve')
        expect(cfg.get('bob.test', :user)).to eq('twelve')

        expect(FileTest.exist?(ENV['HOME'] + '.mrmuranorc'))

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg.get('bob.test', :user)).to eq('twelve')
      end
    end

    it "Sets project values" do # This should write
      Dir.chdir(ENV['HOME']) do
        cfg = MrMurano::Config.new
        cfg.load

        cfg.set('bob.test', 'twelve', :project)

        expect(cfg['bob.test']).to eq('twelve')
        expect(cfg.get('bob.test', :project)).to eq('twelve')

        expect(FileTest.exist?(ENV['HOME'] + '.mrmuranorc'))

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg.get('bob.test', :project)).to eq('twelve')
      end
    end

    it "write a project value and reads it as a user value" do
      Dir.chdir(ENV['HOME']) do
        cfg = MrMurano::Config.new
        cfg.load

        cfg.set('bob.test', 'twelve', :project)

        expect(cfg['bob.test']).to eq('twelve')
        # :user won't have the new value until it is loaded again
        expect(cfg.get('bob.test', :project)).to eq('twelve')

        expect(FileTest.exist?(ENV['HOME'] + '.mrmuranorc'))

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg.get('bob.test', :user)).to eq('twelve')
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
