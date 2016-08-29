require 'json'
require 'rainbow/ext/string'

command :logs do |c|
  c.syntax = %{mr logs [options]}
  c.description = %{Get the logs for a solution}
  #c.option '-f','--follow', %{Follow logs from server}
  c.option('--[no-]color', %{Toggle colorizing of logs}) {
    Rainbow.enabled = false
  }
  c.option '--[no-]pretty', %{Reformat JSON blobs in logs.}

  c.action do |args,options|
    options.default :pretty=>true

    sol = MrMurano::Solution.new
    ret = sol.get('/logs') # TODO: ('/logs?polling=true') Currently ignored.

    if ret.kind_of?(Hash) and ret.has_key?('items') then
      ret['items'].reverse.each do |line|

        line.sub!(/^\[[^\]]*\]/) {|m| m.color(:red).background(:aliceblue)}
        line.sub!(/\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)(?:\+\d\d:\d\d)/) {|m|
          m.color(:blue)
        }

        line.gsub!(/\{(?>[^}{]+|\g<0>)*\}/m) {|m|
          if options.pretty then
            js = JSON.parse(m, {:allow_nan=>true, :create_additions=>false})
            ret = JSON.pretty_generate(js).to_s
            ret.sub!(/^{/){|m| m.color(:magenta)}
            ret.sub!(/^}/){|m| m.color(:magenta)}
          else
            m.color(:green)
          end
        }

        puts line
      end
    else
      say_error "Couldn't get logs: #{ret}"
    end

  end
end
#  vim: set ai et sw=2 ts=2 :
