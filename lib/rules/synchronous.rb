module Rules
  module Synchronous
    extend ActiveSupport::Concern

    module ClassMethods
      
      def raise_event(event_hash)
        event = "#{event_hash[:klazz]}::#{event_hash[:action]}"
        if event_hash[:type] == "ControllerEvent"
          # We also need to check for Rules mapped to ApplicationController::*
          ac_extra_event = "ApplicationController::*"
        end
        Rules::RulesEventAnalytics.track(event_hash)
        if Rules::RulesEngine.all_rules_lookup_map[event] || 
              (ac_extra_event && Rules::RulesEngine.all_rules_lookup_map[ac_extra_event])
          Rules::RulesEngine.handle_event event_hash
        else
          # puts "Not handling unmapped event [#{event}]"
        end

      end
    end
  end
end