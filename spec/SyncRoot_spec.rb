require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/ProjectFile'
require 'MrMurano/SyncRoot'
require 'MrMurano/SyncUpDown'
require '_workspace'

RSpec.describe MrMurano::SyncRoot do
  include_context "WORKSPACE"

  after(:example) do
    MrMurano::SyncRoot.instance.reset
  end

  before(:example) do
    MrMurano::SyncRoot.instance.reset # also creates @@syncset
    class User
    end
    class Role
    end
    MrMurano::SyncRoot.instance.add('user', User, 'U', "describe user", true)
    MrMurano::SyncRoot.instance.add('role', Role, 'R', "describe role")

    # This must happen after all syncables have been added.
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load

    @options = {}
    @options.define_singleton_method(:method_missing) do |mid,*args|
      if mid.to_s.match(/^(.+)=$/) then
        self[$1.to_sym] = args.first
      else
        self[mid]
      end
    end
  end

  it "has defaults" do
    ret = MrMurano::SyncRoot.instance.bydefault
    expect(ret).to eq(['user'])
  end

  it "iterates on each" do
    ret=[]
    MrMurano::SyncRoot.instance.each{|a,b,c| ret << a}
    expect(ret).to eq(["user", "role"])
  end

  it "iterates only on selected" do
    @options.role = true
    ret=[]
    MrMurano::SyncRoot.instance.each_filtered(@options) {|a,b,c,d| ret << a}
    expect(ret).to eq(["role"])
  end

  it "selects all" do
    @options.all = true
    MrMurano::SyncRoot.instance.check_same(@options)
    expect(@options).to eq({:all=>true, :user=>true, :role=>true})
  end

  it "selects defaults when none" do
    MrMurano::SyncRoot.instance.check_same(@options)
    expect(@options).to eq({:user=>true})
  end

  it "selects custom defaults when none" do
    $cfg['sync.bydefault'] = 'role'
    MrMurano::SyncRoot.instance.check_same(@options)
    expect(@options).to eq({:role=>true})
  end

  it "builds option params" do
    ret=[]
    MrMurano::SyncRoot.instance.each_option do |s,l,d|
      ret << [s,l,d]
    end
    expect(ret).to eq([["-u", "--[no-]user", "describe user"], ["-r", "--[no-]role", "describe role"]])
  end

end
#  vim: set ai et sw=2 ts=2 :
