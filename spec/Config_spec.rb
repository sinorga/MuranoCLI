require 'MrMurano/version'
require 'MrMurano/Config'
require 'tempfile'

RSpec.describe MrMurano::Config do
  it "Sets defaults" do
    cfg = MrMurano::Config.new
    cfg.load
    # Don't check for all of them, just a few.
    expect(cfg['files.default_page']).to eq('index.html')
    expect(cfg.get('files.default_page', :defaults)).to eq('index.html')
    expect(cfg['tool.debug']).to eq(false)
    expect(cfg.get('tool.debug', :defaults)).to eq(false)
  end

  # TODO: other tests.
end

#  vim: set ai et sw=2 ts=2 :
