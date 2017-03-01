require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano content', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
      out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', 'contentTest', '--save'))
      expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
  end
  after(:example) do
      out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', 'contentTest'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
  end


  it "life cycle" do
      out, err, status = Open3.capture3(capcmd('murano', 'content', 'list'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      FileUtils.copy(File.join(@testdir, 'spec/fixtures/dumped_config'), 'dumped_config')
      out, err, status = Open3.capture3(capcmd('murano', 'content', 'upload', 'myFile', 'dumped_config', '--meta', 'random junk'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'content', 'list'))
      expect(out).to eq("myFile\n")
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'content', 'info', 'myFile'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to match(/^(\+-+){5}\+$/)
      expect(olines[1]).to match(/^\| \S+\s+\| \d+\s+\| \d+\s+\| random junk\s+\| (false|true)\s+\|$/)
      expect(olines[2]).to match(/^(\+-+){5}\+$/)
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'content', 'download', 'myFile', '-o', 'testDown'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      expect(File.exist?('testDown')).to be true
      expect(FileUtils.cmp('dumped_config', 'testDown')).to be true

      out, err, status = Open3.capture3(capcmd('murano', 'content', 'delete', 'myFile'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'content', 'list'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
