# Last Modified: 2017.08.31 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'fileutils'
require 'open3'
require 'pathname'

require 'highline/import'

require 'cmd_common'

RSpec.describe 'murano help', :cmd do
  include_context 'CI_CMD'

  it 'no args' do
    out, err, status = Open3.capture3(capcmd('murano'))
    expect(err).to eq('')
    expect(out).to_not eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'as --help' do
    out, err, status = Open3.capture3(capcmd('murano', '--help'))
    expect(err).to eq('')
    expect(out).to_not eq('')
    expect(status.exitstatus).to eq(0)
  end

end

