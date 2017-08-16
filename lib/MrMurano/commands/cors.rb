# Last Modified: 2017.08.16 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'yaml'
require 'MrMurano/Webservice-Cors'

command :cors do |c|
  c.syntax = %(murano cors)
  c.summary = %(Get the CORS for the project.)
  c.description = %(
Get the CORS for the project.

Set the CORS with `murano cors set`.
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    sol = MrMurano::Webservice::Cors.new
    ret = sol.fetch
    sol.outf ret
  end
end

command 'cors set' do |c|
  c.syntax = %(murano cors set [<file>])
  c.summary = %(Set the CORS for the project)
  c.description = %(
Set the CORS for the project.
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    crs = MrMurano::Webservice::Cors.new
    file = args.shift
    crs.upload(file)
  end
end

