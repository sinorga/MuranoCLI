# Last Modified: 2017.08.22 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Config'

global_option('--[no-]color', %(Disable fancy output)) do |value|
  HighLine.use_color = value
  Rainbow.enabled = value
end

global_option('-c', '--config KEY=VALUE', %(Set a single config key)) do |param|
  key, value = param.split('=', 2)
  # a=b :> ["a", "b"]
  # a= :> ["a", ""]
  # a :> ["a"]
  raise "Bad config '#{param}'" if key.nil?
  if value.nil?
    $cfg[key] = 'true'
  else
    $cfg[key] = value
  end
end

global_option('-C', '--configfile FILE', %(Load additional configuration file)) do |file|
  # This is called after all of the top level code in this file.
  $cfg.load_specific(file)
end

global_option('-L', '--curl', %(Print out a curl command for each network call)) do
  $cfg['tool.curldebug'] = true
end

global_option('-n', '--dry', %(Do not run actions that make changes)) do
  $cfg['tool.dry'] = true
  # Running dry implies verbose.
  $cfg['tool.verbose'] = true
end

exclude_help = %(
Except config values from the specified scope(s).
        SCOPES can be 1 scope or comma-separated list of
        #{MrMurano::Config::CFG_SCOPES.map(&:to_s)}
).strip
global_option('--exclude-scopes SCOPES', Array, exclude_help) do |value|
  $cfg.exclude_scopes = value.map(&:to_sym)
end

# --no-page is handled early on, in bin/murano.
global_option('--[no-]page', %(Do not page --help output)) do |value|
  $cfg['tool.no-page'] = !value
end

global_option('--[no-]plugins', %(Do not load plugins. Good for when one goes bad))

global_option('--[no-]progress', %(Disable spinner and progress message)) do |value|
  $cfg['tool.no-progress'] = !value
end

global_option('--[no-]ascii', %(Use only ASCII in output)) do |value|
  $cfg['tool.ascii'] = value
end

global_option('-V', '--verbose', %(Be chatty)) do
  $cfg['tool.verbose'] = true
end

