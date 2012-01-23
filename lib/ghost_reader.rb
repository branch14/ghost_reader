%w(backend client util engine).each do |f|
  require File.expand_path(File.join(%w(.. ghost_reader), f), __FILE__)
end

