puts "...Rakefile"
#!/usr/bin/env rake
 
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern =  File.expand_path('../spec/**/*_spec.rb', __FILE__)
end

APP_RAKEFILE = File.expand_path("../spec/dummy/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'

Bundler::GemHelper.install_tasks

load 'lib/tasks/redis_processor.rake'

task :default => :spec

# desc 'Generates a dummy app for testing'
# task :dummy_app => [:setup, :migrate]
 
# task :setup do
#   require 'rails'
#   require 'rules'
#   require 'rules/generators/dummy_generator'
 
#   dummy = File.expand_path('../spec/dummy', __FILE__)
#   sh "rm -rf #{dummy}"
#   MyEngine::DummyGenerator.start(
#     %W(. --quiet --force --skip-bundle --old-style-hash --dummy-path=#{dummy})
#   )
# end
 
# task :migrate do
#   rakefile = File.expand_path('../spec/dummy/Rakefile', __FILE__)
#   sh("rake -f #{rakefile} rules_engine:install:migrations")
#   sh("rake -f #{rakefile} db:create db:migrate db:test:prepare")
# end
