require 'vine'
require 'yaml'
require 'MrMurano/hash'
require 'MrMurano/Setting'

command 'setting list' do |c|
  c.syntax = %{murano setting list}
  c.summary = %{List which services and settings are avalible.}
  c.description = %{
List which services and settings are avalible.
  }.strip
  c.project_not_required = true

  c.action do |args, options|
    setting = MrMurano::Setting.new
    ret = setting.list
    dd=[]
    ret.each_pair{|k,v| v.each{|s| dd << "#{k}.#{s}"}}
    setting.outf dd
  end
end
alias_command 'settings list', 'setting list'

command 'setting read' do |c|
  c.syntax = %{murano setting read <service>.<setting> [<sub-key>]}
  c.summary = %{Read a setting on a Service}
  c.description = %{
Read a setting on a Service.
  }.strip
  c.option '-o', '--output FILE', String, %{File to save output to}

  c.action do |args, options|
    service, pref = args[0].split('.')
    subkey = args[1]

    setting = MrMurano::Setting.new
    ret = setting.read(service, pref)

    ret = ret.access(subkey) unless subkey.nil?

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end
    setting.outf(ret, io)
    io.close unless io.nil?
  end
end

command 'setting write' do |c|
  c.syntax = %{murano setting write <service>.<setting> <sub-key> [<value>...]}
  c.summary = %{Write a setting on a Service}
  c.description = %{
Write a setting on a Service, or just part of a setting.

if <value> is omitted on command line, then it is read from STDIN.

This always does a read-modify-write.

If a sub-key doesn't exist, that entire path will be created as dicts.
  }.strip

  c.option '--bool', %{Set Value type to boolean}
  c.option '--num', %{Set Value type to number}
  c.option '--string', %{Set Value type to string (this is default)}
  c.option '--json', %{Value is parsed as JSON}
  c.option '--array', %{Set Value type to array of strings}
  c.option '--dict', %{Set Value type to a dictionary of strings}

  c.option '--append', %{When sub-key is an array, append values instead of replacing}
  c.option '--merge', %{When sub-key is a dict, merge values instead of replacing (child dicts are also merged)}

  c.example %{murano setting write Gateway.protocol devmode --bool yes}, %{}
  c.example %{murano setting write Gateway.identity_format options.length --int 24}, %{}

  c.example %{murano setting write Webservice.cors methods --array HEAD GET POST}, %{}
  c.example %{murano setting write Webservice.cors headers --append --array X-My-Token}, %{}

  c.example %{murano setting write Webservice.cors --type=json - < }, %{}

  c.action do |args, options|
    options.default :bool => false, :num => false, :string => true, :json => false,
      :array => false, :dict => false, :append => false, :merge => false

    service, pref = args.shift.split('.')
    subkey = args.shift
    value = args.first

    setting = MrMurano::Setting.new

    if subkey.nil? and value.nil? then
      setting.error "Missing value and subkey"
      exit 1
    end

    # If value is '-', pull from $stdin
    if value.nil? and args.count == 0 then
      value = $stdin.read
    end

    # Set value to correct type.
    if options.bool then
      if value =~ /(yes|y|true|t|1|on)/i then
        value = true
      elsif value =~ /(no|n|false|f|0|off)/i then
        value = false
      else
        setting.error %{Value "#{value}" is not a bool type!}
        exit 2
      end
    elsif options.num then
      begin
        value = Integer(value)
      rescue Exception => e
        setting.debug e.to_s
        begin
          value = Float(value)
        rescue Exception => e
          setting.error %{Value "#{value}" is not a number}
          setting.debug e.to_s
          exit 2
        end
      end
    elsif options.json then
      # We use the YAML parser since it will handle most common typos in json and
      # product the intended output.
      begin
        value = YAML.load(value)
      rescue Exception => e
        setting.error %{Value not valid JSON (or YAML)}
        setting.debug e.to_s
        exit 2
      end

    elsif options.array then
      # take remaining args as an array
      value = args

    elsif options.dict then
      # take remaining args and convert to hash
      begin
        value = Hash.transform_keys_to_symbols(Hash[*args])
      rescue ArgumentError => e
        setting.error %{Odd number of arguments to dictionary}
        setting.debug e.to_s
        exit 2
      rescue Exception => e
        setting.error %{Cannot make dictionary from args}
        setting.debug e.to_s
        exit 2
      end

    elsif options.string then
      value = value.to_s
    else
      # is a string.
      value = value.to_s
    end

    ret = setting.read(service, pref)
    setting.verbose %{Read value: #{ret}}

    # modify and merge.
    if options.append then
      g = ret.access(subkey)
      unless g.kind_of? Array then
        setting.error %{Cannot append; "#{subkey}" is not an array.}
        exit 3
      end
      g.push(*value)

    elsif options.merge then
      g = ret.access(subkey)
      unless g.kind_of? Hash then
        setting.error %{Cannot append; "#{subkey}" is not a dictionary.}
        exit 3
      end
      g.deep_merge!(value)
    else
      ret.set(subkey, value)
    end
    setting.verbose %{Going to write composed value: #{ret}}

    setting.write(service, pref, ret)
  end
end

#  vim: set ai et sw=2 ts=2 :

