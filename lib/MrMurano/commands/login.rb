# Last Modified: 2017.07.25 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Account'
require 'MrMurano/Config'

command 'login' do |c|
  c.syntax = %(murano login)
  c.summary = %(Log into Murano)
  c.description = %(
Log into Murano.

If you are having trouble logging in, try deleting the saved password first:

  murano password delete <username>
  ).strip
  c.option '--show-token', %(Shows the API token)
  c.project_not_required = true
  c.prompt_if_logged_off = true

  c.action do |args, options|
    c.verify_arg_count!(args)
    tok = MrMurano::Account.instance.token
    say tok if options.show_token
  end
end

