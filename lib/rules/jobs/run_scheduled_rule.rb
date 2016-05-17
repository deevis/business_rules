module Rules
  module Jobs
    class RunScheduledRule
      @queue = :scheduled_rules

      def self.perform(rule_id)    # Resque-scheduler wants #perform
        puts "Running ScheduledRule[#{rule_id}]"
        r = Rules::Rule.find(rule_id)
        if r.present?
          event = {klazz: r.get_timer_event_class, action: "tick", type: "TimerEvent" }
          puts "  calling process_rule with #{event}"
          r.process_rule(event)
        else 
          puts "  OOPS - we didn't exactly find that rule..."
        end
      rescue => e 
        puts "Error: #{e.message}"
        raise e   # So Scheduler can deal with it perhaps
      end

    end
  end
end