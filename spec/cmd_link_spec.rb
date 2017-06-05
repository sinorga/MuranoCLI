require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano link', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    @solz_name = rname('linktest')
    out, err, status = Open3.capture3(capcmd('murano', 'app', 'create', @solz_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @solz_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'app', 'delete', @solz_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', @solz_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "links and lists" do
    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    expect(out).to a_string_starting_with("Linked #{@solz_name}")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){3}\+$/)
    expect(olines[1]).to match(/^\| name\s+\| script_key\s+\| service\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){3}\+$/)
    expect(olines[-1]).to match(/^(\+-+){3}\+$/)
    expect(status.exitstatus).to eq(0)
  end

  it "unlinks" do
    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    expect(out).to a_string_starting_with("Linked #{@solz_name}")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'link', 'unset'))
    expect(out).to a_string_starting_with("Unlinked #{@solz_name}")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
