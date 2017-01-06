
command 'show' do |c|
  c.syntax = %(mr show)
  c.summary = %(Show readable information about the current configuration)
  c.description = %(Show readable information about the current configuration)
  c.option '--all', 'show verbose information'
  c.option '-a', 'show verbose information'

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
        selectedProduct = row if row[:modelId] == selectedProductId
      end

      selectedSolutionId = $cfg['solution.id']
      selectedSolution = nil
      acc.solutions.each do |row|
        selectedSolution = row if row[:apiId] == selectedSolutionId
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

      if selectedProduct then
        puts %(product: #{selectedProduct[:label]})
      else
        if selectedProductId then
          puts 'selected product not in business'
        else
          puts 'no product selected'
        end
      end

      if selectedSolution then
        puts %(solution: https://#{selectedSolution[:domain]})
      else
        if selectedSolutionId then
          puts 'selected solution not in business'
        else
          puts 'no solution selected'
        end
      end

    end
  end
end

command 'show location' do |c|
  c.syntax = %(mr show location)
  c.summary = %(Show readable location information)
  c.description = %(Show readable information about the current configuration)

  c.action do |args, options|
    puts %(base: #{$cfg['location.base']})
    $cfg['location'].each { |key, value| puts %(#{key}: #{$cfg['location.base']}/#{value}) }
  end
end

#  vim: set ai et sw=2 ts=2 :
