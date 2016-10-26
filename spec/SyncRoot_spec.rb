require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/SyncUpDown'

RSpec.describe MrMurano::SyncRoot do

  after(:example) do
    MrMurano::SyncRoot.reset
  end

  it "Adds" do
    class User
    end
    class Role
    end
    MrMurano::SyncRoot.add('user', User, 'U', "describe user")
    MrMurano::SyncRoot.add('role', Role, 'R', "describe role")
  end

  context "b" do
    before(:example) do
      class User
      end
      class Role
      end
      MrMurano::SyncRoot.add('user', User, 'U', "describe user", true)
      MrMurano::SyncRoot.add('role', Role, 'R', "describe role")

      @options = {}
      @options.define_singleton_method(:method_missing) do |mid,*args|
        if mid.to_s.match(/^(.+)=$/) then
          self[$1.to_sym] = args.first
        else
          self[mid]
        end
      end

    end

    it "iterrates on each" do
      ret=[]
      MrMurano::SyncRoot.each{|a,b,c| ret << a}
      expect(ret).to eq(["user", "role"])
    end

    it "iterrates only on selected" do
      @options.role = true
      ret=[]
      MrMurano::SyncRoot.each_filtered(@options) {|a,b,c| ret << a}
      expect(ret).to eq(["role"])
    end

    it "selects all" do
      @options.all = true
      MrMurano::SyncRoot.checkSAME(@options)
      expect(@options).to eq({:all=>true, :user=>true, :role=>true})
    end

    it "selects defaults when none" do
      MrMurano::SyncRoot.checkSAME(@options)
      expect(@options).to eq({:user=>true})
    end

    it "builds option params" do
      ret=[]
      MrMurano::SyncRoot.each_option do |s,l,d|
        ret << [s,l,d]
      end
      expect(ret).to eq([["-u", "--[no-]user", "describe user"], ["-r", "--[no-]role", "describe role"]])
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
