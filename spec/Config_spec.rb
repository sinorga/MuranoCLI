require 'MrMurano/version'
require 'MrMurano/Config'
require 'tempfile'

RSpec.describe MrMurano::Config do
  it "Sets defaults" do
    cfg = MrMurano::Config.new
    cfg.load
    # Don't check for all of them, just a few.
    expect(cfg['files.default_page']).to eq('index.html')
    expect(cfg.get('files.default_page', :defaults)).to eq('index.html')
    expect(cfg['tool.debug']).to eq(false)
    expect(cfg.get('tool.debug', :defaults)).to eq(false)
  end

  # TODO: other tests.

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

  context "Can find the project directory by .mrmurano/ but not sub .git/" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @projectDir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.mkpath(@projectDir + '/.mrmurano')
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
end

#  vim: set ai et sw=2 ts=2 :
