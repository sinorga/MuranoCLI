require 'date'
require 'json'
require 'rainbow/ext/string'

command :logs do |c|
  c.syntax = %{mr logs [options]}
  c.description = %{Get the logs for a solution}
  c.option '-f','--follow', %{Follow logs from server}
  c.option '--pollrate RATE', Integer, %{Seconds to sleep between polls}
  c.option('--[no-]color', %{Toggle colorizing of logs}) {
    Rainbow.enabled = false
  }
  c.option '--[no-]pretty', %{Reformat JSON blobs in logs.}
  c.option '--[no-]localtime', %{Adjust Timestamps to be in local time}

  c.action do |args,options|
    options.default :pretty=>true, :localtime=>true, :pollrate=>5

    lasttime = ""

    def makePretty(line, options)
      out=''
      if line.has_key?(:type) then
        out << "#{line[:type]} ".upcase.color(:red).background(:aliceblue)
      end
      out << "[#{line[:subject]}]".color(:red).background(:aliceblue)
      out << " "
      if options.localtime then
        curtime = Time.at(line[:timestamp]).localtime.to_datetime.iso8601(3)
      else
        curtime = Time.at(line[:timestamp]).to_datetime.iso8601(3)
      end
      out << curtime.color(:blue)
      out << ":\n"
      if line.has_key?(:data) then
        data = line[:data]

        if data.kind_of?(Hash) and data.has_key?(:request) and data.has_key?(:response) then
          out << "---------\nrequest:"
          if options.pretty then
            ret = JSON.pretty_generate(data[:request]).to_s
            ret[0] = ret[0].color(:magenta)
            ret[-1] = ret[-1].color(:magenta)
            out << ret
          else
            out << data[:request].to_json
          end

          out << "\n---------\nresponse:"
          if options.pretty then
            ret = JSON.pretty_generate(data[:response]).to_s
            ret[0] = ret[0].color(:magenta)
            ret[-1] = ret[-1].color(:magenta)
            out << ret
          else
            out << data[:response].to_json
          end

        else
          out << data.to_s
        end

      else
        out << line.to_s
      end
      out
    end

    sol = MrMurano::Solution.new

    if options.follow then
      # open a lasting connection and continueally feed makePretty()
      begin
        sol.get('/logs?polling=true') do |request, http|
          request["Accept-Encoding"] = "None"
          http.request(request) do |response|
            remainder=''
            response.read_body do |chunk|
              chunk = remainder + chunk unless remainder.empty?

              # for all complete JSON blobs, make them pretty.
              chunk.gsub!(/\{(?>[^}{]+|\g<0>)*\}/m) do |m|
                js = JSON.parse(m, {:allow_nan=>true,
                                    :symbolize_names => true,
                                    :create_additions=>false})
                puts makePretty(js, options)
                '' #remove
              end

              # is there an incomplete one?
              if chunk.match(/(\{.*$)/m) then
                remainder = $1
              end

            end
          end
        end
      rescue Interrupt => e
      end

    else
      ret = sol.get('/logs')

      if ret.kind_of?(Hash) and ret.has_key?(:items) then
        ret[:items].reverse.each do |line|
          puts makePretty(line, options)
        end
      else
        say_error "Couldn't get logs: #{ret}"
        break
      end

    end
  end
end
#  vim: set ai et sw=2 ts=2 :
