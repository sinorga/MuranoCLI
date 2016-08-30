require "bundler/gem_tasks"

#task :default => []

# TODO: figure out better way to test.
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

task :run do
	sh %{ruby -Ilib bin/mr }
end


task :test do
end

#  vim: set sw=4 ts=4 :

