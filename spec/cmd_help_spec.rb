require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano help', :cmd do
  include_context "CI_CMD"

  it "no args" do
    out, err, status = Open3.capture3(capcmd('murano'))
    expect(err).to eq('')
    expect(out).to_not eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "as --help" do
    out, err, status = Open3.capture3(capcmd('murano', '--help'))
    expect(err).to eq('')
    expect(out).to_not eq('')
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
