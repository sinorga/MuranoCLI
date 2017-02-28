require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano account', :cmd, :needs_password do
  include_context "CI_CMD"

  it "Gets a token" do
    out, err, status = Open3.capture3(capcmd('murano', 'account'))
    expect(err).to eq("")
    expect(out).to match(/\h+/)
    expect(status.exitstatus).to eq(0)
  end
end

#  vim: set ai et sw=2 ts=2 :
