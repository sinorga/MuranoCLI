# Last Modified: 2017.08.07 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

module MrMurano
  # NOTE: `rake build` (a task added by postmodern/rubygems-tasks)
  #   replaces the dash in the version with 'rep.', e.g.,
  #     '3.0.0-beta.4.2' changes '3.0.0.pre.beta.4.2'
  #   The build task is from https://github.com/postmodern/rubygems-tasks
  #   The 'dash' in a version is part of http://semver.org/
  # 2017-08-07: We've been cutting GitHub releases for each beta.X,
  #   but not for any beta.X.pre.Y or beta.X-Y
  # NOTE: 3.0.0.beta.5.pre.4 < 3.0.0.beta.5
  VERSION = '3.0.0.beta.5.pre.1'
  EXE_NAME = File.basename($PROGRAM_NAME)
  SIGN_UP_URL = 'https://exosite.com/signup/'
end

