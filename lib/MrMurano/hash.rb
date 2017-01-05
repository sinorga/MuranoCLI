
# from: http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
class Hash
  #take keys of hash and transform those to a symbols
  def self.transform_keys_to_symbols(value)
    return value.map{|v| Hash.transform_keys_to_symbols(v)} if value.is_a?(Array)
    return value if not value.is_a?(Hash)
    hash = value.inject({}){|memo,(k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo}
    return hash
  end
  #take keys of hash and transform those to strings
  def self.transform_keys_to_strings(value)
    return value.map{|v| Hash.transform_keys_to_strings(v)} if value.is_a?(Array)
    return value if not value.is_a?(Hash)
    hash = value.inject({}){|memo,(k,v)| memo[k.to_s] = Hash.transform_keys_to_strings(v); memo}
    return hash
  end
end

#  vim: set ai et sw=2 ts=2 :
