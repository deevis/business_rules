module Rules
  class RuleContext
    # set RuleContext#running_future_action to indicate that a Rule/Action is being accessed from the FutureAction
    attr_accessor :triggers, :index, :actor, :context_guid, :running_future_action, 
                  :url_helpers

    def initialize(event_hash, extras = {})
      @triggers = []
      @index = 0
      @actor = nil
      @context_guid = extras[:rule_context_id] || "#{Time.now.to_i.to_s}-#{Digest::MD5.hexdigest(event_hash.to_s)}"
      @running_future_action = extras[:running_future_action]
      retry_max = 10
      retries = 0
      puts "Rule Context ID being evaluated #{@context_guid}"
      puts "    #{event_hash.keys}"
      event_hash.each do |key, value|
        define_singleton_method(key.to_sym) {value}
      end
      extras.each do |key, value|
        define_singleton_method(key.to_sym) {value}
      end
      define_singleton_method(:system) {:system_messaging_user}
      if extras[:multiple_triggers] # Multiple triggers might occur via TimerEvents where a whole bunch of objects were selected by the criteria
        @triggers = extras[:multiple_triggers].to_a
      else
        @triggers = []
        begin 
          puts "      \nUsing: #{event_hash[:klazz]}  #{event_hash[:id]}"
          if event_hash[:type] == "ModelEvent"
            klazz = event_hash[:klazz].constantize 
            if klazz.respond_to? :fetch
              @triggers << klazz.fetch(event_hash[:id].to_s)
            else
              @triggers << klazz.find(event_hash[:id].to_s)
            end
            puts "      Loaded trigger (#{event_hash[:klazz]}[#{event_hash[:id]}]) for use with RuleContext\n"
          elsif event_hash[:type] == "ControllerEvent"
            puts "      Loaded trigger from controller params #{event_hash[:data]} for use with RuleContext\n"
            @triggers << event_hash[:data]
          elsif event_hash[:type] == "DynamicEvent"
            puts "      Loaded trigger from dynamic_event hash[:data] = #{event_hash[:data]} for use with RuleContext\n"
            @triggers << event_hash[:data]
          elsif event_hash[:trigger].present?
            puts "      Loaded trigger directly from event_hash\n"
            @triggers << event_hash[:trigger]
          else 
            puts "      Not loading trigger for event of type #{event_hash[:type]}"
          end
        rescue => e 
          if retries < retry_max
            retries = retries + 1
            sleep(0.1666)
            puts "    ...retrying trigger lookup for the #{retries} time...(cuz maybe not in db yet)"
            retry 
          else
            puts e.message 
            puts e.backtrace
          end
        end
      end
      puts "     RuleContext created with #{@triggers.size} triggers"
      define_singleton_method(:trigger) { @triggers[@index] rescue nil}
      puts "      Trigger: #{self.trigger.try(:class)}::#{self.trigger.try(:id)}"
      if User.respond_to? :fetch
        @actor = User.fetch event_hash[:user][:id].to_i rescue nil
      end
      @actor ||= User.find event_hash[:user][:id].to_i rescue nil
      @actor ||= self.trigger.try(:user) rescue nil

      define_singleton_method(:actor) { @actor }
      define_singleton_method(:next_trigger) { @index += 1; @triggers[@index] rescue nil}
      define_singleton_method(:url_helpers) { Rails.application.class.routes.url_helpers } 
    end

    def get_binding
      return binding
    end
  end
end

