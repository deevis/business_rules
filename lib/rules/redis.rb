module Rules
  module Redis
    extend ActiveSupport::Concern

    module ClassMethods
      
      def raise_event(event_hash)
        event = "#{event_hash[:klazz]}::#{event_hash[:action]}"
        if event_hash[:type] == "ControllerEvent"
          # We also need to check for Rules mapped to ApplicationController::*
          ac_extra_event = "ApplicationController::*"
        end
        Rules::RulesEventAnalytics.track(event_hash)
        begin
          # An Event may fire both synchronous and asynchronous Rules - let's call the Synchronous ones first as to minimize race conditions
          if Rules::RulesEngine.synchronous_rules_lookup_map[event] || 
              (ac_extra_event && Rules::RulesEngine.synchronous_rules_lookup_map[ac_extra_event])
            t = Time.now
            puts "Processing [#{event}] synchronously"
            Rules::RulesEngine.handle_event event_hash, :synchronous
            puts "Finished processing event in #{Time.now - t} seconds"
          end
          if Rules::RulesEngine.asynchronous_rules_lookup_map[event] ||
             (ac_extra_event && Rules::RulesEngine.asynchronous_rules_lookup_map[ac_extra_event])
            t = Time.now
            puts "Processing [#{event}] asynchronously"
            Redis.new.lpush Rules.redis_queue_name, event_hash
            puts "Pushed event to queue in #{Time.now - t} seconds"
          end
        rescue => e 
          puts "Error processing event[#{event}]: #{e.message}"
          puts e.backtrace
        end

      end
    end
  end
end