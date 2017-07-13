# Last Modified: 2017.07.13 /coding: utf-8
# frozen_string_literal: probably not yet

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano link', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    @solz_name = rname('linktest')
    out, err, status = Open3.capture3(capcmd('murano', 'app', 'create', @solz_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @solz_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'app', 'delete', @solz_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', @solz_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "links and lists" do
    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    #expect(out).to a_string_starting_with("Linked product #{@solz_name}")
    olines = out.lines

    #expect(olines[0]).to eq("Linked ‘#{@solz_name}’ to ‘#{@solz_name}’\n")
# FIXME/2017-07-13: Windows doesn't like the encoding...
    expect(olines[0].encode!('UTF-8', 'UTF-8')).to eq("Linked ‘#{@solz_name}’ to ‘#{@solz_name}’\n")

    expect(olines[1]).to eq("Created default event handler\n")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){3}\+$/)
    expect(olines[1]).to match(/^\| name\s+\| script_key\s+\| service\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){3}\+$/)
    expect(olines[-1]).to match(/^(\+-+){3}\+$/)
    expect(status.exitstatus).to eq(0)
  end

  it "unlinks" do
    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    #expect(out).to a_string_starting_with("Linked product #{@solz_name}")
    olines = out.lines
    expect(olines[0]).to eq("Linked ‘#{@solz_name}’ to ‘#{@solz_name}’\n")
    expect(olines[1]).to eq("Created default event handler\n")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'link', 'unset'))
    #expect(out).to a_string_starting_with("Unlinked #{@solz_name}")
    # E.g.,
    #   Unlinked ‘linktest3e7def1b86a1d680’ from ‘linktest3e7def1b86a1d680’\n
    #   Removed ‘h2thqll2z9sqoooc0_w4w3vxla11ngg4cok_event’ from ‘linktest3e7def1b86a1d680\n
    olines = out.lines
    expect(olines[0]).to eq("Unlinked ‘#{@solz_name}’ from ‘#{@solz_name}’\n")
    expect(olines[1]).to a_string_starting_with("Removed ‘")
    expect(olines[1]).to match(/^Removed ‘[_a-z0-9]*’ from ‘#{@solz_name}’\n$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
end

