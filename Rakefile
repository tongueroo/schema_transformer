require 'rubygems'
require 'rake'
require 'rake/gempackagetask'
require 'spec/rake/spectask'
require 'gemspec'

desc "Generate gemspec"
task :gemspec do
  File.open("#{Dir.pwd}/#{GEM_NAME}.gemspec", 'w') do |f|
    f.write(GEM_SPEC.to_ruby)
  end
end

desc "Install gem"
task :install do
  Rake::Task['gem'].invoke
  $stdout.puts "Installing gem..."
  `gem install pkg/#{GEM_NAME}*.gem`
  `rm -Rf pkg`
end

desc "Package gem"
Rake::GemPackageTask.new(GEM_SPEC) do |pkg|
  pkg.gem_spec = GEM_SPEC
end

desc "Clean up the test project"
task :cleanup do
end