require 'pp'

# XXX This might not work as a command. May need to be a level deeper.
command :shelled do |c|
  c.syntax = %{mr <?...> }
  c.summary = %{Search the PATHs for a subcommand.}

  c.action do |args, options|
    # we are looking for a command in PATH that is longest match to args.
    pp args
    pp options.inspect

    places = ENV['PATH'].split(':').map {|p| Pathname.new(p)}
    pp places

    exit 9
    names = args
    args = []
    while names.count > 0
      test = names.join('-')

      places.each do |bindir|
        if (bindir + test).exist? then
          # Found it.
          # TODO: setup ENV

          options.each_pair do |opt,val|
            # This could be so much smarter.
            args.push "--#{opt}=#{val}"
          end
          exec (bindir+test).path, *args

        end
      end

      args.push names.pop
    end

  end

end

#  vim: set ai et sw=2 ts=2 :
