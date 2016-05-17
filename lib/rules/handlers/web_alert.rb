module Rules
  module Handlers
    class WebAlert < Rules::Handlers::Base

      set_synchronous true
      set_testable true

      needs :level, :select, default: "info", values: ["info", "primary", "success", "warning", "danger"]
      needs :options, :select, optional: true, default: "OK", values: ["OK", "Yes-No", "OK-Cancel"]
      needs :display_priority, :select, optional: true, default: "normal", values: ["normal", "first"]

      template :title
      template :message

      def _handle
        Rails.logger.info "Setting WebAlert Thread locals"
        dp = display_priority
        config = {
          rules_popup_level: level, 
          rules_popup_options: options,         
          rules_popup_display_priority: dp,
          rules_popup_title: eval_template(:title),
          rules_popup_message: eval_template(:message)
        }
        rules_queue =  Rules::WebActionsQueue.get
        # Ok - here's the thing - display priority is intended to work with WebAlerts that
        # are added, possibly from different Rules entirely, in order to make sure that a particular
        # WebAlert is always the first one seen if multiple WebAlerts are added into the same web_actions_queue
        case dp
        when "first" 
          # This one is marked first
          first_web_alert = rules_queue.detect{|r| r[:action_type] == "Rules::Handlers::WebAlert"}
          pos = rules_queue.index(first_web_alert) 
          if pos 
            Rules::WebActionsQueue.insert( self, pos.to_i, config )
          else
            Rules::WebActionsQueue.add( self, config)
          end
        else
          # This one isn't marked first - add it to the end of the list
          Rules::WebActionsQueue.add( self, config)
        end
        config
      rescue => e 
        Rails.logger.error "Not setting WebAlert Thread locals due to exception: #{e.message}"
      end

      def self.test_context(for_action)
        super
      end

    end
  end
end