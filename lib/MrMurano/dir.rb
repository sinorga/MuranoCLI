
## Get the root-most common directories from paths
def Dir.common_dirs(paths)
  paths = paths.map do |p|
    if p.kind_of? Array then
      p
    else
      p.to_s.split(File::SEPARATOR)
    end
  end

  paths.map{|p| p.first}.uniq
end

## How deep is deepest directory path? (not including the file)
def Dir.max_depth(paths)
  paths = paths.map do |p|
    if p.kind_of? Array then
      p
    else
      p.to_s.split(File::SEPARATOR)
    end
  end

  paths.map{|p| p.count - 1}.max

end

## Get the deepest common root directory for all paths
def Dir.common_root(paths, root=[])
  paths = paths.map do |p|
    if p.kind_of? Array then
      p
    else
      p.to_s.split(File::SEPARATOR)
    end
  end

  base = Dir.common_dirs(paths)
  if base.count == 1 then
    return common_root(paths.map{|p| p[1..-1]}, root + base)
  else
    return root
  end
end

#  vim: set ai et sw=2 ts=2 :
