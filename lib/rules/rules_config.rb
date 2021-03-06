module Rules
  class RulesConfig
    
    @@action_type_handlers ||= {}
  
    def self.events_config
      EventConfigLoader.events_dictionary
    end

    def self.event_config(event_name)
      cfg = events_config
      [:model_events, :controller_events, :system_events, :application_events].each do |type|
        ec = cfg[type][event_name]
        unless ec 
          event_name_matched = event_name.match(/(.*)::.*/)[1] rescue "EEEK" # 
          ec = cfg[type][event_name_matched]
        end
        if ec.present?
          ec[:type] = type.to_s.singularize.camelcase
          return ec
        end
      end
      nil
    end

    def self.events
      EventConfigLoader.events_list.select{|e| !e.start_with?("HABTM_")}
    end

    # A very nice hierarchical Hash of all the events
    def self.events_tree
      tree={}
      events_config.keys.sort.each do |event_type|
        events_config[event_type].keys.sort.each do |class_name|
          insert_here = (tree[event_type] ||= {})
          parts = class_name.split("::")
          parts[0...-1].each do |p|
            insert_here = (insert_here[p] ||= {})
          end
          insert_here[parts.last] = events_config[event_type][class_name]
        end
      end
      tree
    end

    def self.add_rule(rule_hash)
      puts "\n\nAdding rule #{rule_hash}"
      event_inclusion = rule_hash.delete(:event_inclusion) rescue nil
      event_exclusion = rule_hash.delete(:event_exclusion) rescue nil
      rule = Rules::Rule.where(:name => rule_hash[:name]).first
      puts "   Updating existing rule..." if rule
      action_configs = rule_hash.delete(:action_configs)
      rule ||= Rules::Rule.create rule_hash
      # Match regexp for inclusions
      events_to_add = EventConfigLoader.events_list.select{|x| x if x.match event_inclusion} if event_inclusion  
      # Match regexp for exclusions
      events_to_restrict = EventConfigLoader.events_list.select{|x| x if x.match event_exclusion} if event_exclusion
      events_to_add = (events_to_add - events_to_restrict) if events_to_restrict
      rule.events = events_to_add
      puts "   Mapped to events: #{rule.events}"
      action_configs.each do |action_config|
        existing_action = rule.actions.detect{|action| action.title == action_config[:title] rescue false}
        rule.actions.create!(action_config) unless existing_action
      end
      rule.set_default_mappings
      rule.save!
      puts "Rule added\n"
      rule
    end

    def self.delete_rules
      Rules::Rule.delete_all
    end

    def self.import_rules(overwrite = false)
      glob_path = "#{Rails.root}/config/rules/*.yml"
      Dir.glob(glob_path).each do |filepath|
        puts "  #{filepath}"
        r = Rules::Rule.import(YAML.load_file(filepath), overwrite: overwrite)
        if r && r.definition_file != filepath
          r.definition_file = filepath
          r.save!
        end
      end
    end

          
    # User friendly dump of the event configuration
    def self.dump_events_config
      events_config.each do |k,v| 
        puts "\n\n\n#{k.to_s.titleize}"
        v.keys.sort.each do |class_name| 
          puts "\n   #{class_name}"
          puts "       - actions"
          v[class_name][:actions].each do |action| 
            puts "           #{action}"
          end
          puts "       - context"
          v[class_name][:context].each do |col_name, col_config| 
            puts "           #{col_name}(#{col_config[:type]})"
          end
        end
      end
      nil
    end

  end
end  
