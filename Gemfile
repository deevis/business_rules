# This gemfile isn't used by business_rules the gem, but rather shows what a client application
# that uses business_rules might need/want to have in its supporting cast
#
# This gemfile is used to run the rails application found in spec/dummy
#
source "http://rubygems.org"

# Declare your gem's dependencies in rules.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gem 'mysql2', '< 0.5'

gem 'sass-rails'
gem 'jquery-rails'
gem 'jquery-ui-rails'

gem 'bootstrap-sass'
gem 'bootswatch-rails'
gem 'font-awesome-rails'

gem 'devise'

gemspec

# jquery-rails is used by the dummy application
# gem 'mongoid', github: 'mongoid/mongoid'  
# gem 'mongoid-versioning', github: 'ream88/mongoid-versioning'
# gem 'identity_cache', github: 'jdatti/identity_cache'

group :development do
  gem 'guard-rspec', require: false
end

# TravisCI wants rake in group test
group :test do
  gem 'database_cleaner'
  gem "rake"
  gem "pry"
  gem 'pry-byebug'
end

gem 'simplecov', :require => false, :group => :test

# gem "rspec", "~> 2.0"
# gem "rspec-rails", "~> 2.0"


# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# To use debugger
# gem 'debugger'
