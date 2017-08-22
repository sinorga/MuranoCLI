# Last Modified: 2017.08.22 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

#require 'MrMurano/progress'
#require 'MrMurano/verbosing'
#require 'MrMurano/hash'

module MrMurano
  module SyncAllowed
    def sync_item_allowed(actioning, item_name)
      if $cfg['tool.dry']
        MrMurano::Verbose.whirly_interject do
          say("--dry: Not #{actioning} item: #{fancy_tick(item_name)}")
        end
        false
      else
        true
      end
    end

    def remove_item_allowed(id)
      sync_item_allowed('removing', id)
    end

    def upload_item_allowed(id)
      sync_item_allowed('uploading', id)
    end

    def download_item_allowed(id)
      sync_item_allowed('downloading', id)
    end

    def removelocal_item_allowed(id)
      sync_item_allowed('removing-local', id)
    end
  end
end

