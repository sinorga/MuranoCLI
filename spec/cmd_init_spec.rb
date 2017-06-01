require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano init', :cmd do
  include_context "CI_CMD"

  def expectedResponseWhenIdsFoundInConfig(t)
    return [
      "\n",
      t.a_string_starting_with('Found project base directory at '),
      "\n",
      t.a_string_starting_with('Using account '),
      "\n",
      t.a_string_starting_with('Using Business ID already set to '),
      "\n",
      t.a_string_starting_with('Using Product ID already set to '),
      "\n",
      t.a_string_starting_with('Using Application ID already set to '),
      "\n",
      t.a_string_matching(%r{Ok, in Business ID: \w+( using Product ID: \w+)?( using Application ID: \w+)?}),
      "\n",
      "Writing an initial Project file: project.murano\n",
      "\n",
      "Default directories created\n",
    ]
  end

  def expectedResponseWhenIdsFetchedFromMurano(t)
    return [
      "\n",
      a_string_starting_with('Found project base directory at '),
      "\n",
      a_string_starting_with('Using account '),
      "\n",
      a_string_starting_with('Using Business ID already set to '),
      "\n",
      a_string_starting_with('You only have one product; using '),
      "\n",
      a_string_starting_with('You only have one application; using '),
      "\n",
      a_string_matching(%r{Ok, in Business ID: \w+( using Product ID: \w+)?( using Application ID: \w+)?}),
      "\n",
      "Writing an initial Project file: project.murano\n",
      "\n",
      "Default directories created\n",
    ]
  end

  it "Won't init in HOME (gracefully)" do
    # this is in the project dir. Want to be in HOME
    Dir.chdir(ENV['HOME']) do
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out).to eq("\n")
      expect(err).to eq("\e[31mCannot init a project in your HOME directory.\e[0m\n")
      expect(status.exitstatus).to eq(2)
    end
  end

  context "in empty directory", :needs_password do
    context "with" do
      # Setup a product and application to use.
      # Doing this in a context with before&after so that after runs even when test
      # fails.
      before(:example) do
        @product_name = rname('initEmptyPrd')
        out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)

        @applctn_name = rname('initEmptyApp')
        out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @applctn_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)

        # delete all of this so it is a empty directory.
        FileUtils.remove_entry('.murano')
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

      it "existing project" do
        # The test account will have one business, one product, and one application.
        # So it won't ask any questions.
        out, err, status = Open3.capture3(capcmd('murano', 'init'))
        expect(out.lines).to match_array(expectedResponseWhenIdsFetchedFromMurano(self))
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

    context "without", :needs_password do
      before(:example) do
        @product_name = rname('initCreatingPrd')
        @applctn_name = rname('initCreatingApp')
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

      it "existing project" do
        # The test account will have one business.
        # It will ask to create an application and product.
        # MAGIC_NUMBER: !!!! the 8 is hardcoded indention here !!!!
        #   (removes the leading whitespace from the <<-EOT heredoc)
        data = <<-EOT.gsub(/^ {8}/, '')
        #{@product_name}
        #{@applctn_name}
        EOT
        out, err, status = Open3.capture3(capcmd('murano', 'init'), :stdin_data=>data)
        expect(out.lines).to match_array([
          "\n",
          a_string_starting_with('Found project base directory at '),
          "\n",
          a_string_starting_with('Using account '),
          a_string_starting_with('Using Business ID already set to '),
          "\n",
          "You do not have any products; let's create one\n",
          "Product Name? \n",
          "\n",
          "You do not have any applications; let's create one\n",
          "Application Name? \n",
          a_string_matching(%r{Ok, in Business ID: \w+( using Product ID: \w+)?( using Application ID: \w+)?}),
          "\n",
          "Writing an initial Project file: project.murano\n",
          "\n",
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

  context "in existing project directory", :needs_password do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')

      @product_name = rname('initEmptyPrd')
      out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
      expect(err).to eq('')
      expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
      expect(status.exitstatus).to eq(0)

      @applctn_name = rname('initEmptyApp')
      out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @applctn_name, '--save'))
      expect(err).to eq('')
      expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
      expect(status.exitstatus).to eq(0)
    end
    after(:example) do
      Dir.chdir(ENV['HOME']) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end
    end

    it "without ProjectFile" do
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array(expectedResponseWhenIdsFoundInConfig(self))
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
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array([
        "\n",
        a_string_starting_with('Found project base directory at '),
        "\n",
        a_string_starting_with('Using account '),
        "\n",
        a_string_starting_with('Using Business ID already set to '),
        "\n",
        a_string_starting_with('Using Product ID already set to '),
        "\n",
        a_string_starting_with('Using Application ID already set to '),
        "\n",
        a_string_matching(%r{Ok, in Business ID: \w+( using Product ID: \w+)?( using Application ID: \w+)?}),
        "\n",
        #"Writing an initial Project file: project.murano\n",
        #"\n",
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
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array(expectedResponseWhenIdsFoundInConfig(self))
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
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out.lines).to match_array(expectedResponseWhenIdsFoundInConfig(self))
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
