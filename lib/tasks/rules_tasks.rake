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
