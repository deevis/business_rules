source "http://rubygems.org"

# Declare your gem's dependencies in rules.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# jquery-rails is used by the dummy application
gem 'mongoid', github: 'mongoid/mongoid'
gem 'mongoid-versioning', github: 'ream88/mongoid-versioning'
# gem 'identity_cache', github: 'jdatti/identity_cache'

group :development do
  gem 'guard-rspec', require: false
end

# TravisCI wants rake in group test
group :test do
  gem 'database_cleaner', '~> 1.0.1'
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
