require 'MrMurano/Product'
require 'MrMurano/hash'
require 'yaml'

command 'product spec convert' do |c|
  c.syntax = %{mr product spec convert FILE}
  c.summary = %{Convert exoline spec file into Murano format}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args, options|
    if args.count == 0 then
      say_error "Missing file"
    else

      File.open(args[0]) do |fin|
        spec = YAML.load(fin)
        unless spec.has_key?('dataports') then
          say_error "Not an exoline spec file"
        else
          dps = spec['dataports'].map do |dp|
            dp.delete_if{|k,v| k != 'alias' and k != 'format' and k != 'initial'}
            dp['format'] = 'string' if dp['format'][0..5] == 'string'
            dp
          end

          spec = {'resource'=>dps}
          if options.output then
            File.open(options.output, 'w') do |io|
              io << spec.to_yaml
            end
          else
            puts spec.to_yaml
          end
        end
      end
    end
  end
end

command 'product spec' do |c|
  c.syntax = %{mr product spec [--file FILE]}
  c.summary = %{Upload a new specification for a product}

  c.option '--file FILE', "The spec file to upload"

  # Search order for file path:
  # - --file FILE
  # - $cfg[ $cfg['product.id'] + '.spec' ]
  # - $cfg['product.spec']

  c.action do |args, options|

    file = $cfg['product.spec']
    prid = $cfg['product.id']
    file = $cfg["p-#{prid}.spec"] unless prid.nil? or $cfg["p-#{prid}.spec"].nil?
    file = options.file unless options.file.nil?

    if not file.nil? and FileTest.exist?(file) then
      prd = MrMurano::Product.new
      pp prd.update(file)
    else
      say_error "No spec file to push: #{file}"
    end
  end
end

command 'product spec pull' do |c|
  c.syntax = %{mr product spec pull [--output FILE]}
  c.summary = %{Pull down the specification for a product}

  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args, options|
    prd = MrMurano::Product.new
    ret = prd.info

    resources = ret[:resources].map do |r|
      r.delete(:rid)
      Hash.transform_keys_to_strings(r)
    end

    spec = { 'resources'=> resources }

    if options.output then
      File.open(options.output, 'w') do |io|
        io << spec.to_yaml
      end
    else
      puts spec.to_yaml
    end
  end

end
#  vim: set ai et sw=2 ts=2 :
