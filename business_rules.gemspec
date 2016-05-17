$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "rules/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "business_rules"
  s.version     = Rules::VERSION
  s.authors     = ["Darren H"]
  s.email       = ["darren.hicks@gmail.com"]
  s.homepage    = "http://buzztrends.net"
  s.summary     = "Business Rules"
  s.description = "Configurable Business Rules for any system, so long as it's Rails..."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
#  s.test_files = Dir["test/**/*"]

  #s.add_dependency "rails"
  # I think we should get these from the parent app when it is running. And
  # all of these gems are being used by parent app anyway, and we need and we are trying
  # to keep all the versions same for a given gem, so there should not be a version conflict issue as-well.

  s.add_dependency "rails", ">= 4.1.1"
  #s.add_dependency "protected_attributes"     # RAILS4_UPGRADE - Backwards Compat
  s.add_dependency "rails-observers"          # RAILS4_UPGRADE - Backwards Compat
  s.add_dependency "jquery-rails"
  s.add_dependency "jquery-ui-rails"
  s.add_dependency "mongoid"
  s.add_dependency "mongoid-versioning"
  s.add_dependency "simple_form"
  s.add_dependency "kaminari", ">=0.13.0"                 # Paging
  s.add_dependency "redis-rails"
  s.add_dependency "obscenity"   
  s.add_dependency "hashie"
  s.add_dependency "httparty"
  s.add_dependency "resque"
  s.add_dependency "resque-status"
  s.add_dependency "resque-scheduler"

  s.add_development_dependency "rspec", "~> 2.0"
  s.add_development_dependency "rspec-rails", "~> 2.0"
  s.add_development_dependency "rspec-expectations", "~> 2.14"
#  s.add_development_dependency "mysql2"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "pry"
  s.add_development_dependency "puma"
  s.add_development_dependency "better_errors"
  s.add_development_dependency "binding_of_caller"
  s.add_development_dependency "meta_request"
  s.add_development_dependency "parallel_tests"
  s.add_development_dependency "simplecov"

  s.add_development_dependency "factory_girl"
end
