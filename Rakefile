require "bundler/gem_tasks"

task :default => [:test]

desc "Install gem in user dir"
task :bob do
    sh %{gem install --user-install pkg/MrMurano-#{Bundler::GemHelper.gemspec.version}.gem}
end

desc "Uninstall from user dir"
task :unbob do
    sh %{gem uninstall --user-install pkg/MrMurano-#{Bundler::GemHelper.gemspec.version}.gem}
end

task :echo do
    puts "= #{Bundler::GemHelper.gemspec.version} ="
end

desc "Push only develop, master, and tags to origin"
task :gitpush do
    sh %{git checkout develop}
    sh %{git push}
    sh %{git checkout master}
    sh %{git push}
    sh %{git push --tags}
end

task :gempush do
    sh %{gem push pkg/MrMurano-#{Bundler::GemHelper.gemspec.version}.gem}
end

task :gemit do
    mrt=Bundler::GemHelper.gemspec.version
    sh %{git checkout v#{mrt}}
    Rake::Task[:build].invoke
    Rake::Task[:bob].invoke
    Rake::Task[:gempush].invoke
    sh %{git checkout develop}
end

task :wexe do
    # Need to find all dlls, because ocra isn't finding them for some reason.
    gemdir = `gem env gemdir`  # XXX can we get that without running commands?
    gemdlls = Dir[File.join(gemdir, 'extensions', '*')]
    sh %{ocra bin/mr #{gemdlls.join(' ')}}
end

desc "Prints a cmd to test this in another directory"
task :testwith do
    pwd=Dir.pwd.sub(Dir.home, '~')
    puts "ruby -I#{pwd}/lib #{pwd}/bin/mr "
end

desc 'Run RSpec'
task :test do
    sh %{rspec}
end

#  vim: set sw=4 ts=4 :

