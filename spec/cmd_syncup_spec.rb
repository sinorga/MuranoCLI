require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano syncup', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    @product_name = rname('syncupTestPrd')
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    @applctn_name = rname('syncdownTestApp')
    out, err, status = Open3.capture3(capcmd('murano', 'app', 'create', @applctn_name, '--save'))
    expect(err).to eq('')
    soln_id = out
    expect(soln_id.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    expect(out).to a_string_starting_with("Linked #{@product_name}")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  context "without ProjectFile" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'), 'specs/resources.yaml')
    end

    it "syncup" do
      out, err, status = Open3.capture3(capcmd('murano', 'syncup'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      # FIXME/2017-06-02 03:06: This is failing. `murano status` shows:
      #   Adding:
      #   Deleting:
      #   Changing:
      #    M M  modules/table_util.lua
      #    M E  services/devdata.lua
      #    M E  services/timers.lua
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      #expect(out).to start_with(%{Adding:\nDeleting:\nChanging:\n})
      expect(out).to start_with(%{Nothing to add\nNothing to delete\nNothing to change\n})
      # Due to timestamp races, there might be modules or services in Changing.
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
    end
  end

  # TODO: With ProjectFile
  # TODO: With Solutionfile 0.2.0
  # TODO: With Solutionfile 0.3.0
end

#  vim: set ai et sw=2 ts=2 :
