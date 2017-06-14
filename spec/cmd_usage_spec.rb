require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano usage', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    @product_name = rname('usageTest')

raise "FIXME: Support for Product(s) and/or Application(s)"
#
# FIXME: Could be either?
# FIXME: Need to run against *all* solutions.
# FIXME: Check other commands to see for cross-solution support...

#    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @product_name, '--save'))
#require 'byebug' ; byebug if true
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "show usage" do
    out, err, status = Open3.capture3(capcmd('murano', 'usage'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){5}\+$/)
    expect(olines[1]).to match(/^\|\s+\| Quota\s+\| Daily\s+\| Monthly\s+\| Total\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){5}\+$/)
    expect(olines[-1]).to match(/^(\+-+){5}\+$/)
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
