require 'fileutils'
require 'open3'
require 'pathname'
require 'json'
require 'cmd_common'

RSpec.describe 'murano status', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    # With an application only, the expected output is different, e.g.,
    #   $ murano application create statusTest --save
    #   $ murano status
    #   Skipping missing location /tmp/d20170602-25639-1xb3al5/project/modules
    #   No product!
    @product_name = rname('statusTest')
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    @applctn_name = rname('statusTest')
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @applctn_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    #out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    #expect(out).to a_string_starting_with("Linked product #{@product_name}")
    #expect(err).to eq('')
    #expect(status.exitstatus).to eq(0)
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
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml')
    end

    # FIXME/2017-06-23: Can maybe remove :not_in_okami if the status command
    #   is returning what we really expect it to; I just copied all the output
    #   from running the command, assuming that all the missing files are
    #   because boilerplate creations. Not confident about "Items that differ", though.
    it "status", :not_in_okami do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      # Two problems with this output.
      # 1: Order of files is not set
      # 2: Path prefixes could be different.
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      expect(olines[1..8]).to contain_exactly(
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        a_string_matching(/ \+ A  .*routes\/singleRoute\.lua/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
      )
      expect(olines[9]).to eq("Only on remote server:\n")
      # FIMXE/2017-06-23: We should DRY this long list which is same in each test.
      # FIXME/2017-06-23: The interfaces the server creates for a new project
      #   will problem vary depending on what modules are loaded, and are likely
      #   to change over time...
      expect(olines[10..31]).to contain_exactly(
        " - E  tsdb_exportJob\n",
        #" - E  timer_timer\n",
        " - E  user_account\n",
        " - E  interface_setIdentityState\n",
        " - E  interface_updateGatewayResource\n",
        " - E  interface_updateIdentity\n",
        " - E  interface_updateGatewaySettings\n",
        " - E  interface_uploadContent\n",
        " - E  interface_getIdentity\n",
        " - E  interface_removeIdentity\n",
        " - E  interface_addIdentity\n",
        " - E  interface_makeIdentity\n",
        " - E  interface_addGatewayResource\n",
        " - E  interface_getGatewayResource\n",
        " - E  interface_listContent\n",
        " - E  interface_clearContent\n",
        " - E  interface_getIdentityState\n",
        " - E  interface_removeGatewayResource\n",
        " - E  interface_getGatewaySettings\n",
        " - E  interface_downloadContent\n",
        " - E  interface_infoContent\n",
        " - E  interface_listIdentities\n",
        " - E  interface_deleteContent\n",
      )
      expect(olines[32]).to eq("Items that differ:\n")
      expect(olines[33..34]).to contain_exactly(
        a_string_matching(/ M E  .*services\/timers\.lua/),
        a_string_matching(/ M E  .*services\/devdata\.lua/),
      )
      expect(status.exitstatus).to eq(0)
    end

    it "matches file path", :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '**/icon.png'))
      expect(err).to eq('')
      expect(out.lines).to match([
        "Only on local machine:\n",
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        "Nothing new remotely\n",
        "Nothing that differs\n",
      ])
      expect(status.exitstatus).to eq(0)
    end

    it "matches route", :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '#put#'))
      expect(err).to eq('')
      expect(out.lines).to match([
        "Only on local machine:\n",
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        "Nothing new remotely\n",
        "Nothing that differs\n",
      ])
      expect(status.exitstatus).to eq(0)
    end
  end

  context "with ProjectFile" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/ProjectFiles/only_meta.yaml'), 'test.murano')
    end

    it "status", :not_in_okami do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      expect(olines[1..8]).to include(
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        a_string_matching(/ \+ A  .*routes\/singleRoute\.lua/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
      )
      expect(olines[9]).to eq("Only on remote server:\n")
      expect(olines[10..31]).to include(
        " - E  tsdb_exportJob\n",
        #" - E  timer_timer\n",
        " - E  user_account\n",
        " - E  interface_setIdentityState\n",
        " - E  interface_updateGatewayResource\n",
        " - E  interface_updateIdentity\n",
        " - E  interface_updateGatewaySettings\n",
        " - E  interface_uploadContent\n",
        " - E  interface_getIdentity\n",
        " - E  interface_removeIdentity\n",
        " - E  interface_addIdentity\n",
        " - E  interface_makeIdentity\n",
        " - E  interface_addGatewayResource\n",
        " - E  interface_getGatewayResource\n",
        " - E  interface_listContent\n",
        " - E  interface_clearContent\n",
        " - E  interface_getIdentityState\n",
        " - E  interface_removeGatewayResource\n",
        " - E  interface_getGatewaySettings\n",
        " - E  interface_downloadContent\n",
        " - E  interface_infoContent\n",
        " - E  interface_listIdentities\n",
        " - E  interface_deleteContent\n",
      )
      #expect(olines[32]).to eq("Nothing that differs\n")
      expect(olines[32]).to eq("Items that differ:\n")
      expect(olines[33..34]).to include(
        a_string_matching(/ M E  .*services\/timers\.lua/),
        a_string_matching(/ M E  .*services\/devdata\.lua/),
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
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml')
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
      expect(olines[0]).to eq("Only on local machine:\n")
      expect(olines[1..7]).to contain_exactly(
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
      )
      expect(olines[8]).to eq("Only on remote server:\n")
      expect(olines[9..31]).to contain_exactly(
        " - E  tsdb_exportJob\n",
        " - E  timer_timer\n",
        " - E  user_account\n",
        " - E  interface_setIdentityState\n",
        " - E  interface_updateGatewayResource\n",
        " - E  interface_updateIdentity\n",
        " - E  interface_updateGatewaySettings\n",
        " - E  interface_uploadContent\n",
        " - E  interface_getIdentity\n",
        " - E  interface_removeIdentity\n",
        " - E  interface_addIdentity\n",
        " - E  interface_makeIdentity\n",
        " - E  interface_addGatewayResource\n",
        " - E  interface_getGatewayResource\n",
        " - E  interface_listContent\n",
        " - E  interface_clearContent\n",
        " - E  interface_getIdentityState\n",
        " - E  interface_removeGatewayResource\n",
        " - E  interface_getGatewaySettings\n",
        " - E  interface_downloadContent\n",
        " - E  interface_infoContent\n",
        " - E  interface_listIdentities\n",
        " - E  interface_deleteContent\n",
      )
      expect(olines[32]).to eq("Items that differ:\n")
      expect(olines[33..33]).to contain_exactly(
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
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml')
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
      expect(olines[0]).to eq("Only on local machine:\n")
      expect(olines[1..7]).to contain_exactly(
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
      )
      expect(olines[8]).to eq("Only on remote server:\n")
      expect(olines[9..31]).to contain_exactly(
        " - E  tsdb_exportJob\n",
        " - E  timer_timer\n",
        " - E  user_account\n",
        " - E  interface_setIdentityState\n",
        " - E  interface_updateGatewayResource\n",
        " - E  interface_updateIdentity\n",
        " - E  interface_updateGatewaySettings\n",
        " - E  interface_uploadContent\n",
        " - E  interface_getIdentity\n",
        " - E  interface_removeIdentity\n",
        " - E  interface_addIdentity\n",
        " - E  interface_makeIdentity\n",
        " - E  interface_addGatewayResource\n",
        " - E  interface_getGatewayResource\n",
        " - E  interface_listContent\n",
        " - E  interface_clearContent\n",
        " - E  interface_getIdentityState\n",
        " - E  interface_removeGatewayResource\n",
        " - E  interface_getGatewaySettings\n",
        " - E  interface_downloadContent\n",
        " - E  interface_infoContent\n",
        " - E  interface_listIdentities\n",
        " - E  interface_deleteContent\n",
      )
      #expect(olines[32]).to eq("Nothing that differs\n")
      expect(olines[32]).to eq("Items that differ:\n")
      expect(olines[33..33]).to contain_exactly(
        a_string_matching(/ M E  .*services\/devdata\.lua/),
      )
      expect(status.exitstatus).to eq(0)
    end
  end

end

#  vim: set ai et sw=2 ts=2 :

