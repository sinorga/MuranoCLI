# Last Modified: 2017.08.29 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

module MrMurano
  class ExchangeElement
    include HashInit

    # The meta is the element hash returned from the platform,
    # i.e., all of the other attrs in a Hash.
    attr_reader :meta

    # The Exchange Element's Business ID context.
    attr_accessor :bizid

    # The Exchange Element's Element ID.
    attr_accessor :elementId
    #attr_accessor :element_id

    # The Purchase ID is nil unless the user has added/purchased this element.
    attr_accessor :purchaseId
    #attr_accessor :purchase_id

    # The <bizId>/exchange/ endpoint returns a list of flat dictionaries.
    # The <bizId>/purchase/ endpoint, on the other hand, puts the remaining
    #   items in an object under an "element" key.

    # The type is one of: download
    attr_accessor :type
    #attr_accessor :action_type

    # The friendly, descriptive name of the Exchange Element.
    attr_accessor :name

    # FIXME/EXPLAIN: Is this what the Lua code calls the service?
    attr_accessor :apiServiceName

    # The image associated with the Exchange Element; not used by the CLI.
    attr_accessor :image

    # The short description describing the Exchange Element.
    attr_accessor :description

    # The long description describing the Exchange Element.
    attr_accessor :markdown

    # The Murano business tiers to which this element applies.
    # One or more of: ["free", "developer", "professional", "enterprise"]
    attr_accessor :tiers

    # Tags used to describe the Exchange Element.
    attr_accessor :tags

    # Actions associated with the Exchange Element.
    attr_accessor :actions
    # The actions is an array with one dict element with:
    #  'url', 'type' (e.g., 'download), and 'primary' (bool).

    # MurCLI-only: Based on purchaseId and tiers, state of Element in Business.
    attr_accessor :status

    ELEM_KEY_TRANSLATE = {
      #type: :action_type,
      #elementId: :element_id,
    }.freeze

    def initialize(*hash)
      hash = [hash] unless hash.is_a? Array
      camel_cased = {}
      hash.first.each do |key, val|
        if ELEM_KEY_TRANSLATE[key].nil?
          camel_cased[key] = val
        else
          camel_cased[ELEM_KEY_TRANSLATE[key]] = val
        end
      end
      super camel_cased
      @meta = hash.first
      #@meta = camel_cased
    end
  end
end

