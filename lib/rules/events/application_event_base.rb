module Rules
  module Events
    class ApplicationEventBase

      # subclassers should override
      def trigger_class
        nil 
      end

      def self.trigger_class
        self.new.trigger_class
      end

      def raise_event(trigger, extras = {})
        raise_event!(trigger, extras)
      rescue => e
        Rails.logger.error "Unable to raise event for #{self} : #{e.message}"
        nil
      end

      def raise_event!(trigger, extras = {})
        return nil if Rules.disabled?
        if trigger_class.present? && !(trigger_class === trigger)
          raise "Cannot raise event with trigger of wrong type.  Got: [#{trigger.class}]   Expected: [#{trigger_class}]"
        end
        event_hash = build_event_hash(trigger, extras)
        Rails.logger.info "#{self.class.name}.raise_event"
        Rules::RulesEngine.raise_event(event_hash)
        return event_hash
      end

      private
        def build_event_hash(trigger, extras={})
            { processing_stack: Rules::Rule.processing_stack, type: "ApplicationEvent", 
              action: "raised", klazz: self.class.name, id: trigger.id, 
                  user: Thread.current[:user] }.merge(extras)
        end
    end
  end
end