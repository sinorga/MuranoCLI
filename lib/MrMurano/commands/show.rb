
command 'show' do |c|
  c.syntax = %(murano show)
  c.summary = %(Show readable information about the current configuration)
  c.description = %(
Show readable information about the current configuration.
  ).strip
  c.project_not_required = true

  c.action do |args, options|

    if args.include?('help') then
      ::Commander::UI.enable_paging
      say MrMurano::SubCmdGroupHelp.new(c).get_help
    else
      acc = MrMurano::Account.new

      selectedBusinessId = $cfg['business.id']
      selectedBusiness = nil
      acc.businesses.each do |row|
        selectedBusiness = row if row[:bizid] == selectedBusinessId
      end

      selectedProductId = $cfg['product.id']
      selectedProduct = nil
      acc.products.each do |row|
        selectedProduct = row if row[:apiId] == selectedProductId
      end

      selectedApplicationId = $cfg['application.id']
      selectedApplication = nil
      acc.applications.each do |row|
        selectedApplication = row if row[:apiId] == selectedApplicationId
      end

      if $cfg['user.name'] then
        puts %(user: #{$cfg['user.name']})
      else
        puts 'no user selected'
      end

      if selectedBusiness then
        puts %(business: #{selectedBusiness[:name]})
      else
        puts 'no business selected'
      end

      # E.g., {:bizid=>"AAAAAAAAAAAAAAAA", :type=>"product",
      #   :apiId=>"BBBBBBBBBBBBBBBBB", :sid=>"BBBBBBBBBBBBBBBBB",
      #   :domain=>"BBBBBBBBBBBBBBBBB.m2.exosite.io", :name=>"AAAAAAAAAAAAAAAA"}
      if selectedProduct then
        puts %(product: #{selectedProduct[:name]})
      else
        if selectedProductId then
          puts 'selected product not in business'
        else
          puts 'no product selected'
        end
      end

      # E.g., {:bizid=>"AAAAAAAAAAAAAAAA", :type=>"application",
      #   :apiId=>"CCCCCCCCCCCCCCCCC", :sid=>"CCCCCCCCCCCCCCCCC",
      #   :domain=>"AAAAAAAAAAAAAAAA.apps.exosite.io", :name=>"AAAAAAAAAAAAAAAA"}
      if selectedApplication then
        puts %(application: https://#{selectedApplication[:domain]})
      else
        if selectedApplicationId then
          puts 'selected application not in business'
        else
          puts 'no application selected'
        end
      end

    end
  end
end

command 'show location' do |c|
  c.syntax = %(murano show location)
  c.summary = %(Show readable location information)
  c.description = %(
Show readable information about the current configuration.
  ).strip
  c.project_not_required = true

  c.action do |args, options|
    puts %(base: #{$cfg['location.base']})
    $cfg['location'].each { |key, value| puts %(#{key}: #{$cfg['location.base']}/#{value}) }
  end
end

#  vim: set ai et sw=2 ts=2 :

