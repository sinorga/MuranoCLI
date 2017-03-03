require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano assign', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'create', 'assigntest', '--save'))
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', 'assigntest', '--save'))
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', 'assigntest'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', 'assigntest'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "status" do
    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){2}\+$/)
    expect(olines[1]).to match(/^\| Label\s+\| ModelID\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){2}\+$/)
    expect(olines[-1]).to match(/^(\+-+){2}\+$/)
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
