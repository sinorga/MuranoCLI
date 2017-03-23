require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'mr init', :cmd do
  include_context "CI_CMD"

  it "Won't init in HOME (gracefully)" do
    # this is in the project dir. Want to be in HOME
    Dir.chdir(ENV['HOME']) do
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out).to eq("\n")
      expect(err).to eq("\e[31mCannot init a project in your HOME directory.\e[0m\n")
      expect(status.exitstatus).to eq(2)
    end
  end

  context "in empty directory" do
    context "with" do
      # Setup a solution and product to use.
      # Doing this in a context with before&after so that after runs even when test
      # fails.
      before(:example) do
        @project_name = rname('initEmpty')
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'create', @project_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @project_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)

        # delete all of this so it is a empty directory.
        FileUtils.remove_entry('.murano')
      end
      after(:example) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end

      it "existing solution and product" do
        # The test account will have one business, one product, and one solution.
        # So it won't ask any questions.
        out, err, status = Open3.capture3(capcmd('murano', 'init'))
        expect(out.lines).to match_array([
          "\n",
          a_string_starting_with('Found project base directory at '),
          "\n",
          a_string_starting_with('Using account '),
          a_string_starting_with('Using Business ID already set to '),
          "\n",
          a_string_starting_with('You only have one solution; using '),
          "\n",
          a_string_starting_with('You only have one product; using '),
          "\n",
          a_string_matching(%r{Ok, In business ID: \w+ using Solution ID: \w+ with Product ID: \w+}),
          "Writing an initial Project file: project.murano\n",
          "Default directories created\n",
        ])
        expect(err).to eq("")
        expect(status.exitstatus).to eq(0)

        expect(File.directory?(".murano")).to be true
        expect(File.exist?(".murano/config")).to be true
        expect(File.directory?("routes")).to be true
        expect(File.directory?("services")).to be true
        expect(File.directory?("files")).to be true
        expect(File.directory?("modules")).to be true
        expect(File.directory?("specs")).to be true
      end
    end

    context "without" do
      before(:example) do
        @project_name = rname('initCreating')
      end
      after(:example) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end

      it "existing solution and product" do
        # The test account will have one business.
        # It will ask to create a solution and product.
        # !!!! the 8 is hardcoded indention here !!!!
        data = <<-EOT.gsub(/^ {8}/, '')
        #{@project_name}
        #{@project_name}
        EOT
        out, err, status = Open3.capture3(capcmd('murano', 'init'), :stdin_data=>data)
        expect(out.lines).to match_array([
          "\n",
          a_string_starting_with('Found project base directory at '),
          "\n",
          a_string_starting_with('Using account '),
          a_string_starting_with('Using Business ID already set to '),
          "\n",
          "You don't have any solutions; lets create one\n",
          "Solution Name? \n",
          "You don't have any products; lets create one\n",
          "Product Name? \n",
          a_string_matching(%r{Ok, In business ID: \w+ using Solution ID: \w+ with Product ID: \w+}),
          "Writing an initial Project file: project.murano\n",
          "Default directories created\n",
        ])
        expect(err).to eq("")
        expect(status.exitstatus).to eq(0)

        expect(File.directory?(".murano")).to be true
        expect(File.exist?(".murano/config")).to be true
        expect(File.directory?("routes")).to be true
        expect(File.directory?("services")).to be true
        expect(File.directory?("files")).to be true
        expect(File.directory?("modules")).to be true
        expect(File.directory?("specs")).to be true
      end
    end
  end

  context "in existing project directory" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')

      @project_name = rname('initEmpty')
      out, err, status = Open3.capture3(capcmd('murano', 'solution', 'create', @project_name, '--save'))
      expect(err).to eq('')
      expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @project_name, '--save'))
      expect(err).to eq('')
      expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
      expect(status.exitstatus).to eq(0)
    end
    after(:example) do
      Dir.chdir(ENV['HOME']) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end
    end

    it "without ProjectFile" do
      # The test account will have one business, one product, and one solution.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array([
        "\n",
        a_string_starting_with('Found project base directory at '),
        "\n",
        a_string_starting_with('Using account '),
        a_string_starting_with('Using Business ID already set to '),
        "\n",
        a_string_starting_with('Using Solution ID already set to '),
        "\n",
        a_string_starting_with('Using Product ID already set to '),
        "\n",
        a_string_matching(%r{Ok, In business ID: \w+ using Solution ID: \w+ with Product ID: \w+}),
        "Writing an initial Project file: project.murano\n",
        "Default directories created\n",
      ])
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end

    it "with ProjectFile" do
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/ProjectFiles/only_meta.yaml'), 'test.murano')
      # The test account will have one business, one product, and one solution.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array([
        "\n",
        a_string_starting_with('Found project base directory at '),
        "\n",
        a_string_starting_with('Using account '),
        a_string_starting_with('Using Business ID already set to '),
        "\n",
        a_string_starting_with('Using Solution ID already set to '),
        "\n",
        a_string_starting_with('Using Product ID already set to '),
        "\n",
        a_string_matching(%r{Ok, In business ID: \w+ using Solution ID: \w+ with Product ID: \w+}),
        "Default directories created\n",
      ])
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end

    it "with SolutionFile 0.2.0" do
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
      # The test account will have one business, one product, and one solution.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array([
        "\n",
        a_string_starting_with('Found project base directory at '),
        "\n",
        a_string_starting_with('Using account '),
        a_string_starting_with('Using Business ID already set to '),
        "\n",
        a_string_starting_with('Using Solution ID already set to '),
        "\n",
        a_string_starting_with('Using Product ID already set to '),
        "\n",
        a_string_matching(%r{Ok, In business ID: \w+ using Solution ID: \w+ with Product ID: \w+}),
        "Writing an initial Project file: project.murano\n",
        "Default directories created\n",
      ])
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end

    it "with SolutionFile 0.3.0" do
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
      # The test account will have one business, one product, and one solution.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array([
        "\n",
        a_string_starting_with('Found project base directory at '),
        "\n",
        a_string_starting_with('Using account '),
        a_string_starting_with('Using Business ID already set to '),
        "\n",
        a_string_starting_with('Using Solution ID already set to '),
        "\n",
        a_string_starting_with('Using Product ID already set to '),
        "\n",
        a_string_matching(%r{Ok, In business ID: \w+ using Solution ID: \w+ with Product ID: \w+}),
        "Writing an initial Project file: project.murano\n",
        "Default directories created\n",
      ])
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end
  end

end
#  vim: set ai et sw=2 ts=2 :
