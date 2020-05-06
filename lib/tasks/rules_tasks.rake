require 'resque'
require 'resque/tasks'
require 'resque/scheduler/tasks'

# nohup bundle exec rake resque:scheduler DYNAMIC_SCHEDULE=true >> log/resque_scheduler.log 2>&1 &
# nohup bundle exec rake resque:workers COUNT=1 >> log/resque_worker.log 2>&1 &
# nohup bundle exec rake rules:redis:processor >> log/rules_redis_processor.log 2>&1 &

task "resque:setup" => :environment

namespace :rules do
  desc "Load Rules from config/rules/*.yml"
  task :load => ['rules:disable', :environment] do
    Rules::RulesConfig.import_rules 
  end

  desc "Load Rules from config/rules/*.yml WITH overwrite=true"
  task :force_load => ['rules:disable', :environment] do
    Rules::RulesConfig.import_rules true
  end

  desc "Clear all Rules from the system"
  task :clear =>  ['rules:disable', :environment] do
    puts "Clean slate activated - deleting existing rules..."
    Rules::RulesConfig.delete_rules
  end
end
