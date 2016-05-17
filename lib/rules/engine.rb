puts "Loading Rules::Engine"
require "rules"
require "mongoid"
require "simple_form"
require "kaminari"
require "rules/all"
require "hashie"
require "identity_cache"

module Rules
  class Engine < ::Rails::Engine

    config.generators do |g|

      g.test_framework :rspec
      # g.test_framework :rspec,
      #   fixtures: false,
      #   view_specs: true,
      #   helper_specs: true,
      #   routing_specs: true,
      #   controller_specs: true,
      #   request_specs: true
      # g.fixture_replacement :factory_girl, :dir => "spec/factories"

      # g.orm :active_record
      g.orm :mongoid 
    end

    config.generators.scaffold_controller = :scaffold_controller

    config.autoload_paths << "#{::Rails.root}/app/rules"
    
    rules_engine = self

    initializer "before_#{self.name.underscore}_initializers1", after: :prepend_helpers_path, before: :load_config_initializers do |app|
      puts "------------------------------------------------------------#{rules_engine.name} - I am CONFIG.AFTER HELPERS ------------------------------------------------------------"
      rules_engine.load_extensions
    end


    config.after_initialize do |app|
      puts "\n\n\nAfter eager_load - loading RulesEngine configuration\n\n\n"
      RulesEngine._reload_configuration  # Only load configuration for our selves, not for the entire cluster necessarily...
    end


    config.to_prepare do |action_dispatcher|
      # More importantly, will run upon every request in development, but only once (during boot-up) in production and test.
      puts "------------------------------------------------------------4:#{rules_engine.name} - I am CONFIG.TO_PREPARE ------------------------------------------------------------"
      puts "------------------------------------------------------------Done with all initializers (from all engines, railties and application. including the initializer files under config/initializers)"

      if Rails.application.initialized?
        rules_engine.load_extensions
      end
    end

    def load_extensions
      puts "\n--- Loading lib/rules for #{self.class.name} "
      Dir.glob("#{self.root}/lib/#{self.class.name.underscore.split("/")[0]}/extensions/**/*.rb").sort.each do |entry|
        
        puts "Reloading extension: #{entry}"
        require_dependency "#{entry}"
      end

      # Dir.glob("#{self.root}/lib/#{self.class.name.split('::').first}/**/*.rb").sort.each do |entry|
      #   next if entry.end_with?("version.rb") || entry.end_with?("engine.rb")
      #   puts "Reloading lib: #{entry}"
      #   require_dependency "#{entry}"
      # end

      Rules.disable! if ENV['RULES_DISABLED'] == 'true'
      if Rules.enabled?
        Dir.glob("#{self.root}/app/models/rules/**/*.rb").sort.each do |entry|
          next if entry.end_with? "version.rb"
          puts "Reloading models: #{entry}"
          require_dependency "#{entry}"
        end
      end
      
      # Dir.glob("#{self.root}/app/rules/rules/**/*.rb").sort.each do |entry|
      #   next if entry.end_with? "version.rb"
      #   puts "Reloading rules: #{entry}"
      #   require_dependency "#{entry}"
      # end

      puts "--- Loaded lib/rules for #{self.class.name} \n"
    end

  end
end

