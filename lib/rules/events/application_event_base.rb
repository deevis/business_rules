module Rules
  module Events
    class ApplicationEventBase

      class_attribute :trigger_class

      # This is the type that will be used for determining the Context the Event will contribute to the Rule  
      def self.set_trigger_class(klazz)
        self.trigger_class = klazz
      end

      def initialize  
      end

      def raise_event(trigger, extras = {})
        return nil if Rules.disabled?
        event_hash = build_event_hash(trigger, extras)
        Rails.logger.info "#{self.class.name}.raise_event:: #{event_hash}"
        Rules::RulesEngine.raise_event(event_hash)
        return event_hash
      rescue => e
        Rails.logger.error "Unable to raise event for #{self} : #{e.message}"
        return nil
      end

      private
        def build_event_hash(trigger, extras={})
            { processing_stack: Rules::Rule.processing_stack, type: self.class.name, 
              action: "system", klazz: trigger.class.name, id: trigger.id, 
                  user: Thread.current[:user] }.merge(extras)
        end
    end
  end
end