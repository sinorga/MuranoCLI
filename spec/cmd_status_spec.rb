require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano status', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'create', 'statustest', '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', 'statustest', '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
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
      expect(err).to eq('')
      # Two problems with this output.
      # 1: Order of files is not set
      # 2: Path prefixes could be different.
      olines = out.lines
      expect(olines[0]).to eq("Adding:\n")
      expect(olines[1..8]).to include(
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        a_string_matching(/ \+ A  .*routes\/singleRoute\.lua/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
      )
      expect(olines[9]).to eq("Deleteing:\n")
      expect(olines[10..11]).to include(
        " - M  my_library\n",
        " - E  user_account\n",
      )
      expect(olines[12]).to eq("Changing:\n")
      expect(olines[13..14]).to include(
        a_string_matching(/ M E  .*services\/devdata\.lua/),
        a_string_matching(/ M E  .*services\/timers\.lua/),
      )
      expect(status.exitstatus).to eq(0)
    end
  end



  # TODO: With ProjectFile
  # TODO: With Solutionfile 0.2.0
  # TODO: With Solutionfile 0.3.0
end

#  vim: set ai et sw=2 ts=2 :
