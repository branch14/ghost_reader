# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ghost_reader/version"

Gem::Specification.new do |s|
  s.name        = "ghost_reader"
  s.version     = GhostReader::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Andreas König", "Phil Hofmann"]
  s.email       = ["koa@panter.ch", "phil@branch14.org"]
  s.homepage    = "https://github.com/branch14/ghost_reader"
  s.summary     = %q{i18n backend to ghost_writer service}
  s.description = %q{Loads I18n-Yaml-Files via http and exchanges statistical data
and updates with the ghost_server}

  s.rubyforge_project = "ghost_reader"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('i18n')
  s.add_dependency('json')

  s.add_development_dependency('rack')
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
  s.add_development_dependency('mongrel')
end
