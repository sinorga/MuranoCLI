require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano account', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    Dir.mkdir(File.join(ENV['HOME'], '.murano'))
    File.open(File.join(ENV['HOME'], '.murano', 'config'), 'w') do |io|
      io << "[user]\n"
      io << "name = #{ENV['MURANO_USER']}\n"
    end
  end

  it "Gets a token" do
    out, err, status = Open3.capture3(capcmd('murano', 'account'))
    expect(err).to eq("")
    expect(out).to match(/\h+/)
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
