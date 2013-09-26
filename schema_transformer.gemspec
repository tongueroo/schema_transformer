# -*- encoding: utf-8 -*-
require File.expand_path('../lib/schema_transformer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tung Nguyen"]
  gem.email         = ["tongueroo@gmail.com"]
  gem.description   = %q{Way is alter database schemas on large tables with little downtime.}
  gem.summary       = %q{Way is alter database schemas on large tables with little downtime.}
  gem.homepage      = "http://github.com/tongueroo/schema_transformer"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "schema_transformer"
  gem.require_paths = ["lib"]
  gem.version       = SchemaTransformer::VERSION

  gem.add_development_dependency 'rspec' # only use to build gem, hack
  gem.add_development_dependency 'mocha' # tests actually use this
  # missing ActiveWrapper because I dont know what version this gem uses

end