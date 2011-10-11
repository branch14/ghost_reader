$:.push File.expand_path("../lib", __FILE__)
require "ghost_reader/version"

Gem::Specification.new do |s|
  s.name        = "ghost_reader"
  s.version     = GhostReader::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Phil Hofmann"]
  s.email       = ["phil@branch14.org"]
  s.homepage    = "https://github.com/branch14/ghost_reader"
  s.summary     = %q{i18n backend to ghost_writer service}
  s.description = %q{i18n backend to ghost_writer service}

  s.rubyforge_project = "ghost_reader"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('i18n')
  s.add_dependency('json')
  s.add_dependency('excon')

  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
  s.add_development_dependency('ruby-debug')
  s.add_development_dependency('guard')
  s.add_development_dependency('guard-rspec')
end
