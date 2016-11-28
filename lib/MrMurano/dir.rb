
## Get the deepest common root directory for all paths
def Dir.common_root(paths, root=[])
  paths = paths.map do |p|
    if p.kind_of? Array then
      p
    else
      p.to_s.split(File::SEPARATOR)
    end
  end

  base = paths.map{|p| p.first}.uniq
  if base.count == 1 then
    return common_root(paths.map{|p| p[1..-1]}, root + base)
  else
    return root
  end
end

#  vim: set ai et sw=2 ts=2 :
