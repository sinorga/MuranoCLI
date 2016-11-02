require 'date'
require 'json'
require 'highline'

module MrMurano
  module Pretties

    HighLine::Style.new(:name=>:on_aliceblue, :code=>"\e[48;5;231m", :rgb=>[240, 248, 255])
    PRETTIES_COLORSCHEME = HighLine::ColorScheme.new do |cs|
      cs[:subject] = [:red, :on_aliceblue]
      cs[:timestamp] = [:blue]
      cs[:json] = [:magenta]
    end
    HighLine.color_scheme = PRETTIES_COLORSCHEME

    def self.makeJsonPretty(data, options)
      if options.pretty then
        ret = JSON.pretty_generate(data).to_s
        ret[0] = HighLine.color(ret[0], :json)
        ret[-1] = HighLine.color(ret[-1], :json)
        ret
      else
        data.to_json
      end
    end

    def self.makePretty(line, options)
      out=''
      out << HighLine.color("#{line[:type] || '--'} ".upcase, :subject)
      out << HighLine.color("[#{line[:subject] || ''}]", :subject)
      out << " "
      if line.has_key?(:timestamp) then
        if line[:timestamp].kind_of? Numeric then
          if options.localtime then
            curtime = Time.at(line[:timestamp]).localtime.to_datetime.iso8601(3)
          else
            curtime = Time.at(line[:timestamp]).gmtime.to_datetime.iso8601(3)
          end
        else
          curtime = line[:timestamp]
        end
      else
        curtime = "<no timestamp>"
      end
      out << HighLine.color(curtime, :timestamp)
      out << ":\n"
      if line.has_key?(:data) then
        data = line[:data]

        if data.kind_of?(Hash) then
          if data.has_key?(:request) and data.has_key?(:response) then
            out << "---------\nrequest:"
            out << makeJsonPretty(data[:request], options)

            out << "\n---------\nresponse:"
            out << makeJsonPretty(data[:response], options)
          else
            out << makeJsonPretty(data, options)
          end
        else
          out << data.to_s
        end

      else
        line.delete :type
        line.delete :timestamp
        line.delete :subject
        out << makeJsonPretty(line, options)
      end
      out
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
