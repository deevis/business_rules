module Rules
  class RulesEngine
    
    @@redis_event_queue = nil
    
    @@async_rules_lookup_map ||= {}
    @@sync_rules_lookup_map ||= {}
    @@all_rules_lookup_map ||= {}
    
    @@semaphore = Mutex.new

    #
    # Rules.activate_event_processing will mixin a strategy to add one of:
    #
    #       Rules::Synchronous
    #       Rules::Redis
    #
    # def self.raise_event
    #

    # event is a hash looking something like:
    # {
    #     type: "ControllerEvent|ModelEvent|TimerEvent|DynamicEvent",
    #     klazz: "ThingsController|User|TimerEvent",
    #     action: "index|create|tick"
    # }
    #
    # For ControllerEvents, the action is the name of the action which was invoked on the controller. ("index", "show", "my_custom", etc...)
    # 
    # For ModelEvents, the action is one of either "create|update|delete"
    #                  for 'update' they have a map of 'changes':
    #                     ['changes']{  'field1': [beforeVal, afterVal],
    #                                   'field2': [beforeVal, afterVal]}
    #
    # For TimerEvents, the action is always "tick"
    #
    # Another valid event_type is "DynamicEvent"
    #
    # For DynamicEvents, the classname and action are loose-freeform and will contain all necessary 
    # values in the :data key.
    #
    #
    # When an event is to be handled, it is looked up by event[:type] from preloaded maps 
    # where each event_type has an entry with a list of Rules that could ultimately fire for that event
    #
    # After the lookup, whatever Rules came back from the cached lookup are then processed with the event as their input.
    #
    def self.handle_event(event, mode = :all, extras = {})
      event = event_from_string(event) if event.class == String
      Rails.logger.debug "RulesEngine.handle_event[Debug]: #{event}"
      event_types = ["#{event[:klazz  ]}::#{event[:action]}"]
      event_classification = event[:type]  # ControllerEvent, ModelEvent, TimerEvent, DynamicEvent
      if event_classification == "ControllerEvent" 
        # If it's any type of ControllerEvent, then also run rules mapped too "ApplicationController::*"
        Rails.logger.debug "Adding ApplicationController::* event to process for actual type #{event}"
        event_types.unshift "ApplicationController::*"
      end
      # Get super event rules tooo?
      event_types.each do |event_type|
        if mode == :asynchronous 
          rules = Rules::RulesEngine.asynchronous_rules_lookup_map[event_type]
        elsif mode == :synchronous
          rules = Rules::RulesEngine.synchronous_rules_lookup_map[event_type]
        else
          rules = Rules::RulesEngine.all_rules_lookup_map[event_type]
        end
        Rails.logger.debug "\n\nGot #{(rules || []).size} Rule to process for #{event_type}\n\n"
        unless rules.blank?
          rules.each do |rule|
            begin
              if event_classification == "ControllerEvent" 
                rri = event[:data]["redirect_rule_id"] 
                if rri.present? && rri == rule.id.to_s
                  Rails.logger.warn "Avoiding redirection infinite loop with rule_redirect_id[#{rri}] - calling next" 
                  next
                end
              end
              rule.process_rule(event, nil, extras)  # rule is either a Rule or a ContinuationStrategy
            rescue => e
              puts "\n\n ERROR ENCOUNTERED processing rule: #{rule.name} ==> #{e.message}"
              puts e.backtrace
            end
          end
        end
      end
    end


    def self.reload_configuration
      if Rules::RulesEngine.respond_to?(:cluster_send) && Rules.event_processing_strategy != :synchronous
        Rules::RulesEngine.cluster_send._reload_configuration
      else
        Rules::RulesEngine._reload_configuration
      end
    end

    def self._reload_configuration
      if Rules.disabled?
        puts "\n\nSkipping RulesEngine.reload_configuration as rules are disabled"
        return
      end
      
      @@semaphore.synchronize do 
        puts "\nRules::RulesEngine.reload_configuration...\n\n"
        events = Rules::EventConfigLoader.reload_events_dictionary
        actions = Rules::Handlers::Base.reload_configuration
        synchronous_rules_lookup_map(true)
        asynchronous_rules_lookup_map(true) 
        all_rules_lookup_map(true)
        return {events: events, actions: actions}
      end
    end      


    def self.sanity_check
      stats = Hash.new(0)
      Rules::Rule.unscoped.all.each do |r| 
        if r.rule_deleted? 
          stats[:deleted] += 1
        else
          stats[:count] += 1 
          r.active? ? stats[:active] +=1 : stats[:inactive] += 1 
          r.ready? ? stats[:valid] += 1 : stats[:invalid] += 1
          r.definition_file.blank? ? stats[:no_yaml_in_source] += 1 : stats[:yaml_in_source] += 1
        end
      end
      stats
    end


    def self.events_dictionary
      Rules::EventConfigLoader.events_dictionary
    end

    def self.async_queue 
      @@redis_event_queue ||= Redis.new(host: Rules.redis_host, port: Rules.redis_port)
    end




    # Event => [Rule/ContinuationStrategy] lookup map
    def self.all_rules_lookup_map(reload = false)
      if @@all_rules_lookup_map == nil || reload
        rules = Rules::Rule.where(active: true)
        @@all_rules_lookup_map = _event_keyed_map_of_rules(rules)
        Rules::Handlers::ContinuationStrategy.registered_strategies.each do |strat|
          (@@all_rules_lookup_map[strat.trigger] ||= []) << strat
        end
      end
      puts "WARN: No Rules to process (@@all_rules_lookup_map)" if @@all_rules_lookup_map.blank?
      @@all_rules_lookup_map
    end

    
    # Event => [Rule/ContinuationStrategy] lookup map
    def self.synchronous_rules_lookup_map(reload = false)
      if @@sync_rules_lookup_map == nil || reload
        rules = Rules::Rule.where(synchronous: true, active: true).select{|r| r.ready?}
        @@sync_rules_lookup_map = _event_keyed_map_of_rules(rules)
      end
      puts "WARN: No Synchronous rules to process (@@sync_rules_lookup_map)" if @@sync_rules_lookup_map.blank?
      @@sync_rules_lookup_map
    end

    # Event => [Rule/ContinuationStrategy] lookup map
    def self.asynchronous_rules_lookup_map(reload = false)
      if @@async_rules_lookup_map == nil || reload
        rules = Rules::Rule.where(:synchronous.ne => true, active: true).select{|r| r.ready?}
        @@async_rules_lookup_map = _event_keyed_map_of_rules(rules)
        # Add ContinuationStrategies into async realm
        Rules::Handlers::ContinuationStrategy.registered_strategies.each do |strat|
          (@@async_rules_lookup_map[strat.trigger] ||= []) << strat
        end
      end
      puts "WARN: No Asynchronous rules to process (@@async_rules_lookup_map)" if @@async_rules_lookup_map.blank?
      @@async_rules_lookup_map
    end

    private
      def self._event_keyed_map_of_rules(rules)
        m = {}
        rules.each do |rule| 
          rule.events.each do |event| 
            # Add all rules that are triggered by TimerEvents to event "TimerEvent::Tick"
            event = "TimerEvent::tick" if event.start_with?("TimerEvent")
            m[event] ||= []
            m[event] << rule 
          end
        end
        m
      end

      # Takes a hash and turns all hash keys into symbols.  It does
      #   this recursively into nested hashes and arrays of hashes
      def event_from_string(event_string)
          event = JSON.parse(event_string)
          HashWithIndifferentAccess.new(event)    # Allow use of symbols or strings as keys
      end

  end


end

