require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano status', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'create', 'statustest', '--save'))
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', 'statustest', '--save'))
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', 'statustest'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', 'statustest'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  context "without ProjectFile" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'), 'specs/resources.yaml')
    end

    it "status" do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(out).to eq( %{Adding:
 + A  routes/manyRoutes.lua
 + A  routes/manyRoutes.lua:4
 + A  routes/manyRoutes.lua:7
 + A  routes/singleRoute.lua
 + S  files/icon.png
 + S  files/index.html
 + S  files/js/script.js
 + M  modules/table_util.lua
Deleteing:
 - M  my_library
 - E  timer_timer
Changing:
 M E  services/devdata.lua
 M E  services/timersAndUsers.lua:3
})
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
    end
  end



  # TODO: With ProjectFile
  # TODO: With Solutionfile 0.2.0
  # TODO: With Solutionfile 0.3.0
end

#  vim: set ai et sw=2 ts=2 :
