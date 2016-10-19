
RSpec.describe 'mr config' do
  describe "Needs a key" do
    command %w{mr config}
    its(:stdout) { is_expected.to include('Need a config key')}
  end

  describe "Set a key" do
    command %w{mr config bob build}
    its(:stdout) { is_expected.to eq('')}
  end
  describe "Reads a key" do
    command %w{mr config test.bob}
    file '.mrmuranorc', <<-EOH
    [test]
    bob=build
    EOH
    its(:stdout) { is_expected.to include('build')}
  end
end

#  vim: set ai et sw=2 ts=2 :
