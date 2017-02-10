require 'MrMurano/Content'

command :content do |c|
  c.syntax = %{murano content}
  c.summary = %{About Content Area}
  c.description = %{This set of commands let you interact with the content area for a product.

This is where OTA data can be stored so that devices can easily download it.
}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'content list' do |c|
  c.syntax = %{murano content list}
  c.summary = %{List downloadable content for a product}
  c.description = %{List downloadable content for a product

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }

  c.option '-l', '--long', %{Include more info for each file}

  c.action do |args, options|
    prd = MrMurano::Content::Base.new
    items = prd.list
    prd.outf(items) do |dd, ios|
      if options.long then
        headers = [:Name, :Id, :Size, :MTime, :MIME]
        rows = dd.map{|d| [d[:tags][:name], d[:id], d[:size], d[:mtime], d[:type]]}
      else
        headers = [:Name, :Size]
        rows = dd.map{|d| [d[:tags][:name], d[:size]]}
      end
      prd.tabularize({:headers=>headers, :rows=>rows}, ios)
    end
  end
end

command 'content info' do |c|
  c.syntax = %{murano content info <content name>}
  c.summary = %{Show more info for a content item}
  c.description = %{Show more info for a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
  c.action do |args, options|
    prd = MrMurano::Content::Base.new
    if args[0].nil? then
      prd.error "Missing <content name>"
    else
      prd.outf(prd.info(args[0])) do |dd,ios|
        ios.puts Hash.transform_keys_to_strings(dd).to_yaml
      end
    end
  end
end

command 'content delete' do |c|
  c.syntax = %{murano content delete <content name>}
  c.summary = %{Delete a content item}
  c.description = %{Delete a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    if args[0].nil? then
      prd.error "Missing <content name>"
    else
      prd.outf prd.remove(args[0])
    end
  end
end

command 'content upload' do |c|
  tags = {}
  c.syntax = %{murano content upload <file>}
  c.summary = %{Upload content}
  c.description = %{Upload a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
  c.option('--tags KEY=VALUE', %{Add extra meta info to the content item}) do |ec|
    key, value = ec.split('=', 2)
    # a=b :> ["a","b"]
    # a= :> ["a",""]
    # a :> ["a"]
    raise "Bad tag key '#{param}'" if key.nil? or key.empty?
    raise "Bad tag value '#{param}'" if value.nil? or value.empty?
    key = key.downcase if key.downcase == 'name'
    tags[key] = value
  end

  c.action do |args, options|
    options.default :meta=>' '
    prd = MrMurano::Content::Base.new

    if args[0].nil? then
      prd.error "Missing <file>"
    else
      name = ::File.basename(args[0])
      name = tags['name'] if tags.has_key? 'name'
      if name.empty? or name.nil? then
        prd.error "Bad file name."
        exit 2
      end

      tags = nil if tags.empty?
      prd.upload(name, args[0], tags)

    end
  end
end

command 'content download' do |c|
  c.syntax = %{murano content download <content name>}
  c.summary = %{Download a content item}
  c.description = %{Download a content item

  Data uploaded to a product's content area can be downloaded by devices using the
  HTTP Device API. (http://docs.exosite.com/http/#list-available-content)
  }
  c.option '-o','--output FILE',%{save to this file}
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    if args[0].nil? then
      prd.error "Missing <content name>"
    else

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
