# Last Modified: 2017.07.02 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Account'
require 'MrMurano/Business'
require 'MrMurano/ReCommander'

command :business do |c|
  c.syntax = %{murano business}
  c.summary = %{About business}
  c.description = %{
Commands for working with businesses.
  }.strip
  c.project_not_required = true

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'business list' do |c|
  c.syntax = %{murano business list [options]}
  c.summary = %{List businesses}
  c.description = %{
List businesses.
  }.strip
  c.option '--idonly', 'Only return the IDs'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}
  c.project_not_required = true

  c.action do |args, options|
    acc = MrMurano::Account.instance

    MrMurano::Verbose.whirly_start 'Looking for businesses...'
    data = acc.businesses
    MrMurano::Verbose.whirly_stop

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    if options.idonly then
      headers = [:bizid]
      data = data.map{|row| [row[:bizid]]}
    elsif not options.all then
      headers = [:bizid, :role, :name]
      data = data.map{|r| [r[:bizid], r[:role], r[:name]]}
    else
      headers = data[0].keys
      data = data.map{|r| headers.map{|h| r[h]}}
    end

    acc.outf(data, io) do |dd, ios|
      if options.idonly then
        ios.puts dd.join(' ')
      else
        acc.tabularize({
          :headers=>headers.map{|h| h.to_s},
          :rows=>dd
        }, ios)
      end
    end
    io.close unless io.nil?

  end
end
alias_command 'businesses list', 'business list'

def business_find_or_ask(acc, ask_user: false)
  match_bid = $cfg.get('business.id', :internal)
  match_name = $cfg.get('business.name', :internal)
  match_either = $cfg.get('business.mark', :internal)
  unless match_bid.to_s.empty? && match_name.to_s.empty? && match_either.to_s.empty?
    biz = business_locate!(acc, match_bid, match_name, match_either)
  else
    biz = business_from_config unless ask_user
    biz = businesses_ask_which if biz.nil?
  end
  # Save the 'business.id' and 'business.name' to the project config.
  biz.write
end

def business_locate!(acc, match_bid, match_name, match_either)
  biz = nil
  bizes = acc.businesses(match_bid, match_name, match_either)
  if bizes.count == 1
    biz = bizes.first
    say("Found business #{biz.pretty_name_and_id}")
    puts('')
  elsif bizes.count > 1
    acc.error('More than one matching business was found. Please be more specific.')
    exit(1)
  else
    acc.error('No matching business was found. Please try again.')
    #say('Please visit Exosite.com to view your account and to create a business:')
    #say("  #{MrMurano::SIGN_UP_URL}")
    exit(1)
  end
  biz
end

def business_from_config
  # By default, creating a new Business object loads its ID from the config.
  biz = MrMurano::Business.new
  unless biz.bid.empty?
    # Verify that the business exists.
    MrMurano::Verbose.whirly_start('Verifying Business...')
    biz.overview
    MrMurano::Verbose.whirly_stop
    if biz.valid?
      say("Found Business #{biz.pretty_name_and_id}")
    else
      say("Could not find Business ‘#{biz.bid}’ referenced in the config")
    end
    puts('')
  end
  biz if biz.valid?
end

def businesses_ask_which(acc)
  biz = nil
  bizes = acc.businesses
  if bizes.count == 1
    biz = bizes.first
    say("This user has one business. Using #{biz.pretty_name_and_id}")
  elsif bizes.count.zero?
    acc.warning('This user has not created any businesses.')
    say('Please log on to exosite.com to create a free account. Visit:')
    say("  #{MrMurano::SIGN_UP_URL}")
    exit 3
  else
    choose do |menu|
      menu.prompt = 'Please select the Business to use:'
      menu.flow = :columns_across
      bizes.sort_by { |a| a.name }.each do |choice|
        menu.choice(choice.name) do
          biz = choice
        end
      end
    end
  end
  puts('')
  biz
end

