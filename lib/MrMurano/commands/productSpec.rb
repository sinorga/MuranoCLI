require 'MrMurano/Account'
require 'MrMurano/Product'
require 'MrMurano/hash'
require 'yaml'
require 'terminal-table'

command 'product spec convert' do |c|
  c.syntax = %{mr product spec convert FILE}
  c.summary = %{Convert exoline spec file into Murano format}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args, options|
    if args.count == 0 then
      say_error "Missing file"
    else
      prd = MrMurano::Product.new
      puts prd.convert(args[0])
    end
  end
end

command 'product spec push' do |c|
  c.syntax = %{mr product spec push [--file FILE]}
  c.summary = %{Upload a new specification for a product [Deprecated]}
  c.description = %{Convert exoline spec file into Murano format

This is deprecated.  Use `mr syncup --specs` instead.
  }

  c.option '--file FILE', "The spec file to upload"

  # Search order for file path:
  # - --file FILE
  # - $cfg[ $cfg['product.id'] + '.spec' ]
  # - $cfg['product.spec']

  c.action do |args, options|
    say_warning "This is deprecated.  Use `mr syncup --specs` instead."

    file = $cfg['product.spec']
    prid = $cfg['product.id']
    file = $cfg["p-#{prid}.spec"] unless prid.nil? or $cfg["p-#{prid}.spec"].nil?
    file = options.file unless options.file.nil?

    if not file.nil? and FileTest.exist?(file) then
      prd = MrMurano::Product.new
      prd.outf prd.update(file)
    else
      say_error "No spec file to push: #{file}"
    end
  end
end

command 'product spec pull' do |c|
  c.syntax = %{mr product spec pull [--output FILE]}
  c.summary = %{Pull down the specification for a product}

  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}
  c.option '--astable', %{Display as pretty table}
  c.option '--aliasonly', 'Only return the aliases'

  c.action do |args, options|
    prd = MrMurano::Product.new
    ret = prd.info

    output = ''
    if options.aliasonly then
      output = ret[:resources].map{|row| row[:alias]}.join(' ')

    elsif options.astable then
      busy = ret[:resources].map{|r| [r[:alias], r[:format], r[:rid]]}
      output = Terminal::Table.new :rows => busy, :headings => ['Alias', 'Format', 'RID']

    else
      resources = ret[:resources].map do |r|
        r.delete(:rid)
        Hash.transform_keys_to_strings(r)
      end
      spec = { 'resources'=> resources }
      output = spec
    end

    if options.output then
      File.open(options.output, 'w') do |io|
        io << output.to_yaml
      end
    else
      prd.outf output
    end
  end
end
alias_command 'product spec', 'product spec pull'
alias_command 'product spec list', 'product spec pull', '--astable'

#  vim: set ai et sw=2 ts=2 :
