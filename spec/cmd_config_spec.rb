
RSpec.describe 'mr config' do
  def read_temp(path)
    puts temp_path
    IO.read(File.join(temp_path, path))
  end

  describe "Needs a key" do
    command %w{mr config}
    its(:stdout) { is_expected.to include('Need a config key')}
    its(:stderr) { is_expected.to eq('')}
  end

  describe "Set a key" do
    command %w{mr config bob build}
    its(:stdout) { is_expected.to eq('')}
    its(:stderr) { is_expected.to eq('')}
  end

  describe "Reads a key" do
    command %w{mr config --project doThisTest.bob}
    fixture_file '.mrmuranorc'
    its(:stdout) { is_expected.to include('build')}
    its(:stderr) { is_expected.to eq('')}
  end

  describe "Removes a key" do
    command %{mr config --project --unset doThisTest.bob}
    fixture_file '.mrmuranorc'
    its(:stdout) { is_expected.to eq('')}
    its(:stderr) { is_expected.to eq('')}
    it { is_expected.to match_fixture 'mrmuranorc_deleted_bob' }
    #it {expect(read_temp('.mrmuranorc')).to eq('[test]')}
  end
end

#  vim: set ai et sw=2 ts=2 :
