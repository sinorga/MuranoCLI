# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require_relative 'lib/MrMurano/version.rb'

Gem::Specification.new do |s|
  s.name        = 'MrMurano'
  s.version     = MrMurano::VERSION
  s.authors     = ['Michael Conrad Tadpol Tilstra']
  s.email       = ['tadpol@tadpol.org']
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/tadpol/MrMurano'
  s.summary     = 'Do more from the command line with Murano'
  s.description = %{Do more from the command line with Murano

  Push and pull data from Murano.
  Get status on what things have changed.
  See a diff of the changes before you push.

  and so much more.
  }

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency('commander', '~> 4.4.0')
  s.add_runtime_dependency('terminal-table', '~> 1.4.5')
  s.add_runtime_dependency('mime-types', '~> 1.25.1')
  s.add_runtime_dependency('mime-types-data', '~> 3.2016')
  s.add_runtime_dependency('inifile', '~> 3.0')
  s.add_runtime_dependency('http-form_data', '~> 1.0.1')
  s.add_runtime_dependency('rainbow', '~> 2.1.0')
  s.add_runtime_dependency('dotenv', '~> 2.1.1')

  s.add_development_dependency('bundler', '~> 1.7.6')
  s.add_development_dependency('rake', '~> 10.1.1')
  s.add_development_dependency('rspec', '~> 3.5')
  s.add_development_dependency('webmock', '~> 2.1.0')
  # maybe? s.add_development_dependency('vcr', '~> ???')
end


