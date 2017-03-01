require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano device', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', 'devcietest', '--save'))
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', 'devcietest'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "enables and lists" do
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'enable', '12345'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){3}\+$/)
    expect(olines[1]).to match(/^\| SN\s+\| Status\s+\| RID\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){3}\+$/)
    expect(olines[3]).to match(/^\| 12345\s+\| notactivated\s+\| \h{40}\s+\|$/)
    expect(olines[4]).to match(/^(\+-+){3}\+$/)
    expect(status.exitstatus).to eq(0)
  end

  it "activates" do
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'enable', '12345'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'activate', '12345'))
    expect(out.chomp).to match(/^\h{40}$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "writes and reads" do
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'enable', '12345'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'activate', '12345'))
    expect(out.chomp).to match(/^\h{40}$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'twee', '12345', '--trace'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
