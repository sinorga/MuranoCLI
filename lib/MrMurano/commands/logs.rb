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

    sol = MrMurano::Solution.new
    begin
      begin
        ret = sol.get('/logs') # TODO: ('/logs?polling=true') Currently ignored.

        if ret.kind_of?(Hash) and ret.has_key?(:items) then
          ret[:items].reverse.each do |line|
            curtime = ""
            if line.kind_of?(String) then

              line.sub!(/^\[[^\]]*\]/) {|m| m.color(:red).background(:aliceblue)}
              line.sub!(/\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)(?:\+\d\d:\d\d)/) {|m|
                if options.localtime then
                  m = DateTime.parse(m).to_time.localtime.to_datetime.iso8601(3)
                end
                curtime = m
                m.color(:blue)
              }

              line.gsub!(/\{(?>[^}{]+|\g<0>)*\}/m) do |m|
                if options.pretty then
                  js = JSON.parse(m, {:allow_nan=>true, :create_additions=>false})
                  ret = JSON.pretty_generate(js).to_s
                  ret[0] = ret[0].color(:magenta)
                  ret[-1] = ret[-1].color(:magenta)
                  ret
                else
                  m.sub!(/^{/){|ml| ml.color(:magenta)}
                  m.sub!(/}$/){|ml| ml.color(:magenta)}
                  m
                end
              end

              out = line

            elsif line.kind_of?(Hash) then
              out=""

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

            end

            if curtime > lasttime then
              lasttime = curtime
              puts out
            end

          end
        else
          say_error "Couldn't get logs: #{ret}"
          break
        end

        sleep(options.pollrate) if options.follow
      end while options.follow
    rescue Interrupt => e
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
