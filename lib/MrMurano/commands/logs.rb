require 'MrMurano/Solution'
require 'MrMurano/makePretty'

command :logs do |c|
  c.syntax = %{murano logs [options]}
  c.summary = %{Get the logs for a solution}
  c.description = %{
Get the logs for a solution.
  }.strip
  c.option '-f','--follow', %{Follow logs from server}
  c.option('--[no-]color', %{Toggle colorizing of logs}) {
    # EXPLAIN/2017-06-14: [lb] curious if this the same as rainbow gem I added.
    #   I also do not think this --color/--no-color option is used
    Rainbow.enabled = false
  }
  c.option '--[no-]pretty', %{Reformat JSON blobs in logs.}
  c.option '--[no-]localtime', %{Adjust Timestamps to be in local time}
  c.option '--raw', %{Don't do any formating of the log data}

  # Add the flags: --types, --ids, --names, --[no]-header.
  command_add_solution_pickers c

  c.action do |args,options|
    options.default :pretty=>true, :localtime=>true, :raw => false

raise "FIXME: Support for Product(s) and/or Application(s)"
#
# FIXME: Could be either?
    sol = MrMurano::Solution.new
#    sol = MrMurano::Product.new
#    sol = MrMurano::Application.new

    if options.follow then
      # open a lasting connection and continually feed makePretty()
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
                  begin
                    js = JSON.parse(m, {:allow_nan=>true,
                                        :symbolize_names => true,
                                        :create_additions=>false})
                    puts MrMurano::Pretties::makePretty(js, options)
                  rescue
                    sol.error '=== JSON parse error, showing raw instead ==='
                    puts m
                  end
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
            puts MrMurano::Pretties::makePretty(line, options)
          end
        end
      else
        sol.error "Couldn't get logs: #{ret}"
        break
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :

