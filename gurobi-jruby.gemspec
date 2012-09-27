Gem::Specification.new do |gem|
  gem.name        = 'gurobi-jruby'
  gem.version     = '0.0.0'
  gem.summary     = %q{Gurobi Optimizer for JRuby}
  gem.description = gem.summary

  gem.homepage    = 'https://github.com/m4i/gurobi-jruby'
  gem.license     = 'MIT'
  gem.author      = 'Masaki Takeuchi'
  gem.email       = 'm.ishihara@gmail.com'

  gem.files       = `git ls-files`.split($/)
  gem.executables = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files  = gem.files.grep(%r{^(test|spec|features)/})

  gem.required_ruby_version = '>= 1.9.3'

  gem.add_development_dependency 'rake', '~> 0.9.2.2'
end
