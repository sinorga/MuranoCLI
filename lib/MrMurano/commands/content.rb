require 'MrMurano/Product'

command 'content list' do |c|
  c.syntax = %{mr content list}
  c.summary = %{List downloadable content for a product}
  c.description = %{List downloadable content for a product

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    prd.list.each{|item| say item}
  end
end
alias_command :content, 'content list'

command 'content info' do |c|
  c.syntax = %{mr content info <content id>}
  c.summary = %{Show more info for a content item}
  c.description = %{Show more info for a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
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
  c.summary = %{Delete a content item}
  c.description = %{Delete a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
  c.action do |args, options|
    if args[0].nil? then
      say_error "Missing <content id>"
    else
      prd = MrMurano::ProductContent.new
      prd.outf prd.remove(args[0])
    end
  end
end

command 'content upload' do |c|
  c.syntax = %{mr content upload <content id> <file>}
  c.summary = %{Upload content}
  c.description = %{Upload a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
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
        prd.outf prd.create(args[0], options.meta)
      end

      prd.outf prd.upload(args[0], args[1])
    end
  end
end

command 'content download' do |c|
  c.syntax = %{mr content download <content id>}
  c.summary = %{Download a content item}
  c.description = %{Download a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
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
