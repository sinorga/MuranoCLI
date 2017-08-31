# Last Modified: 2017.08.29 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

# 2017-07-01: This ordered list hacks around having
# individual files include all the files they need.

require 'MrMurano/version'

require 'MrMurano/hash'
require 'MrMurano/http'
require 'MrMurano/makePretty'
#require 'MrMurano/optparse'
require 'MrMurano/progress'
require 'MrMurano/verbosing'

require 'MrMurano/Config'
require 'MrMurano/Config-Migrate'
require 'MrMurano/ProjectFile'

require 'MrMurano/Account'
require 'MrMurano/Business'
require 'MrMurano/Passwords'

require 'MrMurano/Content'
require 'MrMurano/Gateway'
require 'MrMurano/Keystore'
require 'MrMurano/Mock'
require 'MrMurano/Setting'
require 'MrMurano/SolutionId'
require 'MrMurano/Solution'
require 'MrMurano/Solution-Services'
require 'MrMurano/Solution-ServiceConfig'
require 'MrMurano/Solution-Users'
require 'MrMurano/Webservice'
require 'MrMurano/Webservice-Cors'
require 'MrMurano/Webservice-Endpoint'
require 'MrMurano/Webservice-File'

require 'MrMurano/SyncAllowed'
require 'MrMurano/SyncRoot'
require 'MrMurano/SyncUpDown'

require 'MrMurano/SubCmdGroupContext'
require 'MrMurano/ReCommander'
require 'MrMurano/commands'

