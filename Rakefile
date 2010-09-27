require 'rubygems'
require 'rake'

$LOAD_PATH.unshift('lib')

begin
  INSTALL_MESSAGE = %q{
  ========================================================================
  Turkee Installation Complete.
  ------------------------------------------------------------------------
  Please run the generator to copy the needed javascript file
  into your application:
    rails generator turkee:install # Rails 3
    ./script/generate turkee       # Rails 2

  For instructions on gem usage, visit:
    http://github.com/aantix/turkee#readme
  ========================================================================
  }
  
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "turkee"
    gem.summary = "Turkee makes dealing with Amazon's Mechnical Turk a breeze."
    gem.description = "Turkee will help you to create your Rails forms, post the HITs, and retrieve the user entered values from Mechanical Turk."
    gem.email = "jjones@aantix.com"
    gem.homepage = "http://github.com/aantix/turkee"
    gem.authors = ["Jim Jones"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "rturk", ">= 2.3.0"    
    gem.post_install_message = INSTALL_MESSAGE
    gem.require_path = 'lib'
    gem.files = %w(MIT-LICENSE README.textile Rakefile init.rb) + Dir.glob("{generators,lib,spec}/**/*")
    
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "turkee #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
