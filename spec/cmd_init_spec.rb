require 'fileutils'
require 'open3'
require 'pathname'
require 'tmpdir'

RSpec.describe 'mr init' do

  pwd = Pathname.new(Dir.pwd).realpath
  pref = "ruby -I#{(pwd+'lib').to_s} #{(pwd+'bin').to_s}/"

  around(:example) do |ex|
    @testdir = Dir.pwd
    Dir.mktmpdir do |hdir|
      ENV['HOME'] = hdir
      Dir.chdir(hdir) do
        @tmpdir = File.join(hdir, 'project')
        Dir.mkdir(@tmpdir)
        Dir.chdir(@tmpdir) do
          ex.run
        end
      end
    end
  end

  it "Won't init in HOME (gracefully)" do
    # this is in the project dir. Want to be in HOME
    Dir.chdir(ENV['HOME']) do
      out, err, status = Open3.capture3("#{pref}mr init --trace")
      expect(out).to eq("")
      expect(err).to eq("\e[31mCannot init a project in your HOME directory.\e[0m\n")
      expect(status.exitstatus).to eq(2)
    end
  end

  it "Asks to import if Solutionfile exists" do
    FileUtils.touch('Solutionfile.json')
    out, err, status = Open3.capture3("#{pref}mr init --trace", :stdin_data=>'y')
    expect(out).to eq("A Solutionfile.json exists, Do you want exit and run `mr config import` instead? [yN]\n")
    expect(err).to eq("")
    expect(status.exitstatus).to eq(0)
  end

end
#  vim: set ai et sw=2 ts=2 :
