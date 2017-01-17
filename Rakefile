require "bundler/gem_tasks"
require 'shellwords'

task :default => [:test]

tagName = "v#{Bundler::GemHelper.gemspec.version}"
gemName = "MrMurano-#{Bundler::GemHelper.gemspec.version}.gem"
builtGem = "pkg/#{gemName}"

desc "Install gem in user dir"
task :bob do
    sh %{gem install --user-install #{builtGem}}
end

desc "Uninstall from user dir"
task :unbob do
    sh %{gem uninstall --user-install #{builtGem}}
end

task :echo do
    puts tagName
    puts gemName
    puts builtGem
end

namespace :git do
    desc "Push only develop, master, and tags to origin"
    task :origin do
        sh %{git push origin develop}
        sh %{git push origin master}
        sh %{git push origin --tags}
    end

    desc "Push only develop, master, and tags to upstream"
    task :upstream do
        sh %{git push upstream develop}
        sh %{git push upstream master}
        sh %{git push upstream --tags}
    end

    desc "Push to origin and upstream"
    task :all => [:origin, :upstream]
end

task :gemit do
    mrt=Bundler::GemHelper.gemspec.version
    sh %{git checkout v#{mrt}}
    Rake::Task[:build].invoke
    Rake::Task[:bob].invoke
    Rake::Task['push:gem'].invoke
    sh %{git checkout develop}
end

namespace :push do
    desc 'Push gem up to RubyGems'
    task :gem do
        sh %{gem push #{builtGem}}
    end

    namespace :github do
        desc "Make a release in Github"
        task :makeRelease do
            # ENV['GITHUB_TOKEN'] set by CI.
            # ENV['GITHUB_USER'] set by CI.
            # ENV['GITHUB_REPO'] set by CI
            # Create Release
            sh %{github-release info --tag #{tagName}} do |ok, res|
                if not ok then
                    sh %{github-release release --tag #{tagName}}
                end
            end
        end

        desc 'Push gem up to Github Releases'
        task :gem => [:makeRelease, :build] do
            # ENV['GITHUB_TOKEN'] set by CI.
            # ENV['GITHUB_USER'] set by CI.
            # ENV['GITHUB_REPO'] set by CI
            # upload gem
            sh %{github-release upload --tag #{tagName} --name #{gemName} --file #{builtGem}}
        end

        desc "Copy tag commit message into Release Notes"
        task :copyReleaseNotes do
            tagMsg = `git tag -l -n999 #{tagName}`.lines
            tagMsg.shift
            msg = tagMsg.join().shellescape
            sh %{github-release edit --tag #{tagName} --description #{msg}}
        end
    end
end

desc "Prints a cmd to test this in another directory"
task :testwith do
    pwd=Dir.pwd.sub(Dir.home, '~')
    puts "ruby -I#{pwd}/lib #{pwd}/bin/mr "
end

desc 'Run RSpec'
task :rspec do
    Dir.mkdir("report") unless File.directory?("report")
    sh %{rspec --format html --out report/index.html --format progress}
end
task :test => [:rspec]

file "ReadMe.txt" => ['README.markdown'] do |t|
    File.open(t.prerequisites.first) do |rio|
        File.open(t.name, 'w') do |wio|
            wio << rio.read.gsub(/\n/,"\r\n")
        end
    end
end

if Gem.win_platform? then
    file 'mr.exe' => Dir['lib/MrMurano/**/*.rb'] do
        # Need to find all dlls, because ocra isn't finding them for some reason.
        gemdir = `gem env gemdir`.chomp
        gemdlls = Dir[File.join(gemdir, 'extensions', '*')]
        ENV['RUBYLIB'] = 'lib'
        sh %{ocra bin/mr #{gemdlls.join(' ')}}
    end
    task :wexe => ['mr.exe']

    desc 'Run rspec on cmd tests using mr.exe'
    task :mr_exe_test => ['mr.exe'] do
        Dir.mkdir("report") unless File.directory?("report")
        ENV['CI_MR_EXE'] = '1'
        files = Dir[File.join('spec', 'cmd_*_spec.rb')]
        sh %{rspec --format html --out report/mr_exe.html --format progress #{files.join(' ')}}
    end
    task :test => [:mr_exe_test]

    installerName = "Output/MrMurano-#{Bundler::GemHelper.gemspec.version.to_s}-Setup.exe"

    desc "Build a Windows installer for MrMurano"
    task :inno => [installerName]

    file "Output/MrMuranoSetup.exe" => ['mr.exe', 'ReadMe.txt'] do
        ENV['MRVERSION'] = Bundler::GemHelper.gemspec.version.to_s
        sh %{"C:\\Program Files (x86)\\Inno Setup 5\\iscc.exe" MrMurano.iss}
    end
    file installerName => ['Output/MrMuranoSetup.exe'] do |t|
        FileUtils.move t.prerequisites.first, t.name, :verbose=>true
    end

    namespace :push do
        namespace :github do
            desc "Push Windows installer to Github Releases"
            task :inno => [:makeRelease, installerName] do
                # ENV['GITHUB_TOKEN'] set by CI.
                # ENV['GITHUB_USER'] set by CI.
                # ENV['GITHUB_REPO'] set by CI
                iname = File.basename(installerName)
                sh %{github-release upload --tag #{tagName} --name #{iname} --file #{installerName}}
            end
        end
    end
end

#  vim: set sw=4 ts=4 :

