require 'date'
require 'json'
require 'rainbow/ext/string'

command :logs do |c|
  c.syntax = %{mr logs [options]}
  c.description = %{Get the logs for a solution}
  c.option '-f','--follow', %{Follow logs from server}
  c.option('--[no-]color', %{Toggle colorizing of logs}) {
    Rainbow.enabled = false
  }
  c.option '--[no-]pretty', %{Reformat JSON blobs in logs.}
  c.option '--[no-]localtime', %{Adjust Timestamps to be in local time}
  c.option '--raw', %{Don't do any formating of the log data}

  c.action do |args,options|
    options.default :pretty=>true, :localtime=>true, :raw => false

    def makeJsonPretty(data, options)
      if options.pretty then
        ret = JSON.pretty_generate(data).to_s
        ret[0] = ret[0].color(:magenta)
        ret[-1] = ret[-1].color(:magenta)
        ret
      else
        data.to_json
      end
    end

    def makePretty(line, options)
      out=''
      out << "#{line[:type] || '--'} ".upcase.color(:red).background(:aliceblue)
      out << "[#{line[:subject] || ''}]".color(:red).background(:aliceblue)
      out << " "
      if line.has_key?(:timestamp) then
        if options.localtime then
          curtime = Time.at(line[:timestamp]).localtime.to_datetime.iso8601(3)
        else
          curtime = Time.at(line[:timestamp]).to_datetime.iso8601(3)
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
                if options.raw then
                  puts m
                else
                  js = JSON.parse(m, {:allow_nan=>true,
                                      :symbolize_names => true,
                                      :create_additions=>false})
                  puts makePretty(js, options)
                end
                '' #remove (we're kinda abusing gsub here.)
              end

              # is there an incomplete one?
              if chunk.match(/(\{.*$)/m) then
                remainder = $1
              end

            end
          end
        end
      rescue Interrupt => _
      end

    else
      ret = sol.get('/logs')

      if ret.kind_of?(Hash) and ret.has_key?(:items) then
        ret[:items].reverse.each do |line|
          if options.raw then
            puts line
          else
            puts makePretty(line, options)
          end
        end
      else
        say_error "Couldn't get logs: #{ret}"
        break
      end

    end
  end
end
#  vim: set ai et sw=2 ts=2 :
