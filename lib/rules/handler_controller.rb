module Rules
  module HandlerController
    def self.included(base)
			base.before_filter :clear_rules_thread_locals
			base.after_filter :move_thread_locals_to_flash

			def clear_rules_thread_locals
				Thread.current[:redirect_url] = nil
				Thread.current[:rules_popup_message] = nil
				Thread.current[:rules_popup_title] = nil
			end

			def move_thread_locals_to_flash
				# puts "TODO: Move any unprocessed threadlocals to flash scope"
				if Thread.current[:rules_popup_message]
					flash[:rules_popup_level] = Thread.current[:rules_popup_level]
					flash[:rules_popup_message] = Thread.current[:rules_popup_message]
					flash[:rules_popup_title] = Thread.current[:rules_popup_title]
					Thread.current[:rules_popup_level] = nil
					Thread.current[:rules_popup_message] = nil
					Thread.current[:rules_popup_title] = nil
				end
				flash[:redirect_url] = Thread.current[:redirect_url]
				Thread.current[:redirect_url] = nil
			end
		end
	end
end