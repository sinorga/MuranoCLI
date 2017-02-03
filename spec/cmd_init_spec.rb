require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'mr init' do
  include_context "CI_CMD"

  it "Won't init in HOME (gracefully)" do
    # this is in the project dir. Want to be in HOME
    Dir.chdir(ENV['HOME']) do
      out, err, status = Open3.capture3(capcmd('murano', 'init', '--trace'))
      expect(out).to eq("\n")
      expect(err).to eq("\e[31mCannot init a project in your HOME directory.\e[0m\n")
      expect(status.exitstatus).to eq(2)
    end
  end

  it "Asks to import if Solutionfile exists" do
    FileUtils.touch('Solutionfile.json')
    out, err, status = Open3.capture3(capcmd('murano', 'init', '--trace'), :stdin_data=>'y')
    expect(out).to eq("\nA Solutionfile.json exists, Do you want exit and run `mr config import` instead? [yN]\n")
    expect(err).to eq("")
    expect(status.exitstatus).to eq(0)
  end

end
#  vim: set ai et sw=2 ts=2 :
