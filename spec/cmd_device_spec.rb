require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano device', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    @project_name = rname('deviceTest')
    out, err, status = Open3.capture3(capcmd('murano', 'project', 'create', @project_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @project_name))
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
    expect(olines[1]).to match(/^\| Identifier\s+\| Status\s+\| Online\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){3}\+$/)
    expect(olines[3]).to match(/^\| 12345\s+\| whitelisted\s+\| false\s+\|$/)
    expect(olines[4]).to match(/^(\+-+){3}\+$/)
    expect(status.exitstatus).to eq(0)
  end

  it "enables a batch" do
    File.open('ids.csv', 'w') do |io|
      io << "ID\n"
      io << "1234\n"
      io << "1235\n"
      io << "1236\n"
    end

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'enable', '--file', 'ids.csv'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){3}\+$/)
    expect(olines[1]).to match(/^\| Identifier\s+\| Status\s+\| Online\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){3}\+$/)
    expect(olines[3]).to match(/^\| 1234\s+\| whitelisted\s+\| false\s+\|$/)
    expect(olines[4]).to match(/^\| 1235\s+\| whitelisted\s+\| false\s+\|$/)
    expect(olines[5]).to match(/^\| 1236\s+\| whitelisted\s+\| false\s+\|$/)
    expect(olines[6]).to match(/^(\+-+){3}\+$/)
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

  it "writes and reads" do # [lb]
    FileUtils.mkpath('specs')
    FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'), 'specs/resources.yaml')

    out, err, status = Open3.capture3(capcmd('murano', 'syncup', '--resources'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'enable', '12345'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'activate', '12345'))
    expect(out.chomp).to match(/^\h{40}$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

#    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'twee', '12345'))
#    expect(err).to eq('')
#    olines = out.lines
#    expect(olines[0]).to match(/^(\+-+){4}\+$/)
#    expect(olines[1]).to match(/^\|\s+12345\s+activated\s+\|$/)
#    expect(olines[2]).to match(/^(\+-+){4}\+$/)
#    expect(olines[3]).to match(/^\| Resource\s+\| Format\s+\| Modified\s+\| Value\s+\|$/)
#    expect(olines[4]).to match(/^(\+-+){4}\+$/)
#    expect(olines[-1]).to match(/^(\+-+){4}\+$/)
#    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'write', '12345', 'state=42'))
    expect(out).to eq("")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'device', 'read', '12345', 'state'))
    #expect(out.strip).to eq('42')
    expect(err).to eq('')
    expect(out.lines).to match_array([
      /^(\+-+){4}\+$/,
      /^\| Alias\s+\| Reported\s+\| Set\s+\| Timestamp\s+\|$/,
      /^(\+-+){4}\+$/,
      /^\| state\s+\| \s+\| 42\s+\| \d+\s+\|$/,
      /^(\+-+){4}\+$/,
    ])
    expect(status.exitstatus).to eq(0)

  end

end

#  vim: set ai et sw=2 ts=2 :
