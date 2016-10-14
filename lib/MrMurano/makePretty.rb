require 'date'
require 'json'
require 'rainbow/ext/string'

module MrMurano
  module Pretties
    def self.makeJsonPretty(data, options)
      if options.pretty then
        ret = JSON.pretty_generate(data).to_s
        ret[0] = ret[0].color(:magenta)
        ret[-1] = ret[-1].color(:magenta)
        ret
      else
        data.to_json
      end
    end

    def self.makePretty(line, options)
      out=''
      out << "#{line[:type] || '--'} ".upcase.color(:red).background(:aliceblue)
      out << "[#{line[:subject] || ''}]".color(:red).background(:aliceblue)
      out << " "
      if line.has_key?(:timestamp) then
        if line[:timestamp].kind_of? Numeric then
          if options.localtime then
            curtime = Time.at(line[:timestamp]).localtime.to_datetime.iso8601(3)
          else
            curtime = Time.at(line[:timestamp]).to_datetime.iso8601(3)
          end
        else
          curtime = line[:timestamp]
        end
      else
        curtime = "<no timestamp>"
      end
      out << curtime.color(:blue)
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
