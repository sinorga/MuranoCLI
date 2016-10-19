
RSpec.describe 'mr config' do
    command %w{mr config}
    its(:stdout) { is_expected.to include('Need a config key')}
end

#  vim: set ai et sw=2 ts=2 :
