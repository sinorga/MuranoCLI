
command 'content list' do |c|
  c.syntax = %{mr content list}
  c.description = %{List downloadable content for a product}
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    prd.list.each{|item| say item}
  end
end
alias_command :content, 'content list'

command 'content info' do |c|
  c.syntax = %{mr content info <content id>}
  c.description = %{Show more info for a content item}
  c.action do |args, options|
    if args[0].nil? then
      say_error "Missing <content id>"
    else
      prd = MrMurano::ProductContent.new
      prd.info(args[0]).each{|line| say "#{args[0]} #{line.join(' ')}"}
    end
  end
end

command 'content delete' do |c|
  c.syntax = %{mr content delete <content id>}
  c.description = %{Delete a content item}
  c.action do |args, options|
    if args[0].nil? then
      say_error "Missing <content id>"
    else
      prd = MrMurano::ProductContent.new
      pp prd.remove(args[0])
    end
  end
end

command 'content upload' do |c|
  c.syntax = %{mr content upload <content id> <file>}
  c.description = %{Upload content}
  c.option '--meta STRING', %{Add extra meta info to the content item}

  c.action do |args, options|
    options.defaults :meta=>' '

    if args[0].nil? then
      say_error "Missing <content id>"
    elsif args[1].nil? then
      say_error "Missing <file>"
    else
      prd = MrMurano::ProductContent.new

      ret = prd.info(args[0])
      if ret.nil? then
        pp prd.create(args[0], options.meta) # FIXME: bad headers?
      end

      pp prd.upload(args[0], args[1])
    end
  end
end

command 'content download' do |c|
  c.syntax = %{mr content download <content id>}
  c.description = %{Download a content item}
  c.option '-o','--output FILE',%{save to this file}
  c.action do |args, options|
    if args[0].nil? then
      say_error "Missing <content id>"
    else
      prd = MrMurano::ProductContent.new

      if options.output.nil? then
        prd.download(args[0]) # to stdout
      else
        outFile = Pathname.new(options.output)
        outFile.open('w') do |io|
          prd.download(args[0]) do |chunk|
            io << chunk
          end
        end
      end
    end
  end
end


#  vim: set ai et sw=2 ts=2 :
