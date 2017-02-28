require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano business', :cmd, :needs_password do
  include_context "CI_CMD"

  context "list" do
    it "as table" do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list'))
      expect(err).to eq("")
      olines = out.lines
      expect(olines[0]).to match(/^(\+-+){3}\+$/)
      expect(olines[1]).to match(/^\| bizid\s+\| role\s+\| name\s+\|$/)
      expect(olines[2]).to match(/^(\+-+){3}\+$/)
      expect(olines[-1]).to match(/^(\+-+){3}\+$/)
      expect(status.exitstatus).to eq(0)
    end

    it "as json" do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list', '-c', 'outformat=json'))
      expect(err).to eq("")
      expect{JSON.parse(out)}.to_not raise_error
      expect(status.exitstatus).to eq(0)
    end

    it "only ids" do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list', '--idonly', ))
      expect(err).to eq("")
      expect(out).to match(/^(\S+\s)*\S+$/)
      expect(status.exitstatus).to eq(0)
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
