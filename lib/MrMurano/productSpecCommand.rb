require 'MrMurano/Product'
require 'MrMurano/hash'
require 'yaml'

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
    file = $cfg[ prid + '.spec'] unless prid.nil? or $cfg[ prid + '.spec'].nil?
    file = options.file unless options.file.nil?

    if FileTest.exist?(file) then
      prd = MrMurano::Product.new
      pp prd.update(file)
    else
      say_error "File Missing: #{file}"
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

    spec = ret[:resources].map do |r|
      r.delete(:rid)
      Hash.transform_keys_to_strings(r)
    end

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
