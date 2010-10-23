require 'lib/schema_transformer/version'

GEM_NAME = 'schema_transformer'
GEM_FILES = FileList['**/*'] - FileList['coverage', 'coverage/**/*', 'pkg', 'pkg/**/*']
GEM_SPEC = Gem::Specification.new do |s|
  # == CONFIGURE ==
  s.author = "Tung Nguyen"
  s.email = "tongueroo@gmail.com"
  s.homepage = "http://github.com/tongueroo/#{GEM_NAME}"
  s.summary = "Way is alter database schemas on large tables with little downtime"
  # == CONFIGURE ==
  s.executables += [GEM_NAME]
  s.extra_rdoc_files = [ "README.markdown" ]
  s.files = GEM_FILES.to_a
  s.has_rdoc = false
  s.name = GEM_NAME
  s.platform = Gem::Platform::RUBY
  s.require_path = "lib"
  s.version = SchemaTransformer::VERSION
end
