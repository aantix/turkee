# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = %q{turkee}
  s.version = "2.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Jim Jones}]
  s.date = %q{2013-05-14}
  s.description = %q{Turkee will help you to easily create usability studies, post HITs, and retrieve the user entered values from Mechanical Turk.}
  s.email = %q{jjones@aantix.com}
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.homepage = %q{http://github.com/aantix/turkee}
  s.post_install_message = %q{
  ========================================================================
  Turkee Installation Complete.
  ------------------------------------------------------------------------

  If you're upgrading, be sure to execute the following to receive the
  latest migration changes.
    rails g turkee --skip

  (the skip flag will ensure that you don't overwrite prior
  Turkee initializers and migrations)


  For instructions on gem usage, visit:
    http://github.com/aantix/turkee#readme

  ========================================================================
  -- Gobble, gobble.
  }
  s.require_paths = [%q{lib}]
  s.rubygems_version = %q{1.8.1}
  s.summary = %q{Turkee makes dealing with Amazon's Mechnical Turk a breeze.}

  s.add_dependency(%q<lockfile>)
  s.add_dependency(%q<rails>, [">= 3.1.1"])
  s.add_dependency(%q<rturk>, [">= 2.4.0"])

  s.add_development_dependency "mocha"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "spork"
  s.add_development_dependency "pry-byebug"
  s.add_development_dependency "pry-rescue"
  s.add_development_dependency "webmock", '1.11.0'
  s.add_development_dependency "vcr"

  # RSpec has to be in both test and development so that rake tasks and generators
  # are available without having to explicitly switch the environment to 'test'
  s.add_development_dependency 'factory_girl', '>= 1.3.2'
  s.add_development_dependency "rspec-rails", "~> 2.6"
end

