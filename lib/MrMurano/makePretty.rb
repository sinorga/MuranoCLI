# Last Modified: 2017.08.20 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'date'
require 'json'
require 'highline'

module MrMurano
  module Pretties
    HighLine::Style.new(name: :on_aliceblue, code: "\e[48;5;231m", rgb: [240, 248, 255])
    PRETTIES_COLORSCHEME = HighLine::ColorScheme.new do |cs|
      cs[:subject] = %i[red on_aliceblue]
      cs[:timestamp] = [:blue]
      cs[:json] = [:magenta]
    end
    HighLine.color_scheme = PRETTIES_COLORSCHEME
    SEVERITYS = %w[emergency alert critical error warning notice info debug].freeze
    # rubocop:disable Style/MethodName: "Use snake_case for method names."
    def self.makeJsonPretty(data, options)
      if options.pretty
        ret = JSON.pretty_generate(data).to_s
        ret[0] = HighLine.color(ret[0], :json)
        ret[-1] = HighLine.color(ret[-1], :json)
        ret
      else
        data.to_json
      end
    end

    def self.makePretty(line, options)
      # 2017-07-02: Changing shovel operator << to +=
      # to support Ruby 3.0 frozen string literals.
      out = ''
      out += HighLine.color("#{SEVERITYS[line[:severity]] || '--'} ".upcase, :subject)
      out += HighLine.color("[#{line[:service] || ''}:#{line[:event] || ''}]", :subject)
      out += ' '
      if line.key?(:timestamp)
        if line[:timestamp].is_a? Numeric
          if options.localtime
            curtime = Time.at(line[:timestamp] / 1000.0).localtime.to_datetime.iso8601(3)
          else
            curtime = Time.at(line[:timestamp] / 1000.0).gmtime.to_datetime.iso8601(3)
          end
        else
          curtime = line[:timestamp]
        end
      else
        curtime = '<no timestamp>'
      end
      out += HighLine.color(curtime, :timestamp)
      out += ":\n"
      if line.key?(:message)
        data = line[:message]

        if data.is_a?(Hash)
          if data.key?(:request) && data.key?(:response)
            out += "---------\nrequest:"
            out += makeJsonPretty(data[:request], options)

            out += "\n---------\nresponse:"
            out += makeJsonPretty(data[:response], options)
          else
            out += makeJsonPretty(data, options)
          end
        else
          out += data.to_s
        end

      else
        line.delete :type
        line.delete :timestamp
        line.delete :subject
        out += makeJsonPretty(line, options)
      end
      out
    end
  end
end
