require 'fileutils'
require 'open3'
require 'pathname'
require 'json'
require 'cmd_common'

RSpec.describe 'murano status', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    @project_name = rname('statusTest')
    out, err, status = Open3.capture3(capcmd('murano', 'project', 'create', @project_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'project', 'delete', @project_name))
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

    it "status", :not_in_okami do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      # Two problems with this output.
      # 1: Order of files is not set
      # 2: Path prefixes could be different.
      olines = out.lines
      expect(olines[0]).to eq("Adding:\n")
      expect(olines[1..8]).to contain_exactly(
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
      expect(olines[10..12]).to contain_exactly(
        " - E  gateway_disconnect\n",
        " - E  gateway_connect\n",
        " - E  user_account\n",
      )
      expect(olines[13]).to eq("Changing:\n")
      expect(olines[14..15]).to contain_exactly(
        a_string_matching(/ M E  .*services\/devdata\.lua/),
        a_string_matching(/ M E  .*services\/timers\.lua/),
      )
      expect(status.exitstatus).to eq(0)
    end

    it "matches file path", :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '**/icon.png'))
      expect(err).to eq('')
      expect(out.lines).to match([
        "Adding:\n",
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        "Deleteing:\n",
        "Changing:\n",
      ])
      expect(status.exitstatus).to eq(0)
    end

    it "matches route", :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '#put#'))
      expect(err).to eq('')
      expect(out.lines).to match([
        "Adding:\n",
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        "Deleteing:\n",
        "Changing:\n",
      ])
      expect(status.exitstatus).to eq(0)
    end
  end

  context "with ProjectFile" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'), 'specs/resources.yaml')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/ProjectFiles/only_meta.yaml'), 'test.murano')
    end

    it "status", :not_in_okami do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
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
      expect(olines[10..12]).to include(
        " - E  user_account\n",
        " - E  gateway_connect\n",
        " - E  gateway_disconnect\n",
      )
      expect(olines[13]).to eq("Changing:\n")
      expect(olines[14..15]).to include(
        a_string_matching(/ M E  .*services\/devdata\.lua/),
        a_string_matching(/ M E  .*services\/timers\.lua/),
      )
      expect(status.exitstatus).to eq(0)
    end
  end

  # XXX wait, should a Solutionfile even work with Okami?
  context "with Solutionfile 0.2.0", :not_in_okami do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'), 'specs/resources.yaml')
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          :default_page => 'index.html',
          :file_dir => 'files',
          :custom_api => 'routes/manyRoutes.lua',
          :modules => {
            :table_util => 'modules/table_util.lua'
          },
          :event_handler => {
            :device => {
              :datapoint => 'services/devdata.lua'
            }
          }
        }.to_json
      end
    end

    it "status" do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      # Not a single match, because the order of items within groups can shift
      olines = out.lines
      expect(olines[0]).to eq("Adding:\n")
      expect(olines[1..7]).to contain_exactly(
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
      )
      expect(olines[8]).to eq("Deleteing:\n")
      expect(olines[9..12]).to contain_exactly(
        " - E  timer_timer\n",
        " - E  user_account\n",
        " - E  gateway_connect\n",
        " - E  gateway_disconnect\n",
      )
      expect(olines[13]).to eq("Changing:\n")
      expect(olines[14..15]).to contain_exactly(
        a_string_matching(/ M E  .*services\/devdata\.lua/),
      )
      expect(status.exitstatus).to eq(0)
    end
  end

  # XXX wait, should a Solutionfile even work with Okami?
  context "with Solutionfile 0.3.0", :not_in_okami do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'), 'specs/resources.yaml')
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          :default_page => 'index.html',
          :assets => 'files',
          :routes => 'routes/manyRoutes.lua',
          :modules => {
            :table_util => 'modules/table_util.lua'
          },
          :services => {
            :device => {
              :datapoint => 'services/devdata.lua'
            }
          },
          :version => '0.3.0',
        }.to_json
      end
    end

    it "status" do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to eq("Adding:\n")
      expect(olines[1..7]).to contain_exactly(
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
      )
      expect(olines[8]).to eq("Deleteing:\n")
      expect(olines[9..12]).to contain_exactly(
        " - E  user_account\n",
        " - E  timer_timer\n",
        " - E  gateway_connect\n",
        " - E  gateway_disconnect\n",
      )
      expect(olines[13]).to eq("Changing:\n")
      expect(olines[14..15]).to contain_exactly(
        a_string_matching(/ M E  .*services\/devdata\.lua/),
      )
      expect(status.exitstatus).to eq(0)
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
