module Rules
	module ControllerEventEmitter

		@@registered_classes = []

		def self.included(base)
			#base.send :extend, ClassMethods
			#unless ( File.basename($0) == "rake" && ARGV.include?("db:migrate") )
			#end
			base.before_filter :raise_controller_event
			@@registered_classes << base if !@@registered_classes.index(base)
		end

		def self.registered_classes
			@@registered_classes
		end

		private
		  def raise_controller_event(extras = {})
				return if Rules.disabled?
				action = params[:action]
				event_hash = build_event_hash("ControllerEvent", self.class.name, action, extras)
				Rules::RulesEngine.raise_event(event_hash)
				# Enhancement - if Rules were put in place to perform a redirect, then do the
				#               redirect immediately here in the Filter!
				web_actions_queue = Rules::WebActionsQueue.get
				if web_actions_queue.present? && 
					 web_actions_queue.first[:action_type] == "Rules::Handlers::WebRedirect" && 
					 !request.xhr?
					# If this is not an Ajax request, then perform a redirect right now
					redirect_now = web_actions_queue.shift 
					Rules::WebActionsQueue.clear
					Rules::WebActionsQueue.store_queue(web_actions_queue, params, session)
					url = redirect_now[:redirect_url]
					Rails.logger.info "Pro-actively redirecting from within before_filter: #{url}"
					if !url.start_with? "http"
						url = "#{PyrCore::AppSetting.server_url}/#{url}" 
						Rails.logger.info "Using fully qualified url: #{url}"
					end
					redirect_to url
				end
		  end

		  #
		  # event_type: ["ControllerEvent", "ModelEvent", "TimerEvent", "DynamicEvent"]
		  #
		  # class_name: String
		  # action_name: String 
		  #
		  # Ultimately the rule is matched via "#{class_name}::#{action_name}"
		  #
			def build_event_hash(event_type, class_name, action, extras={})
					filtered_params = Rules.data_filter.filter params.dup
					event_hash = { processing_stack: Rules::Rule.processing_stack, type: event_type, klazz: self.class.name, 
													action: action, data: filtered_params, user: Rules.current_user.call,
													xhr: request.xhr?, ip: request.remote_ip, user_agent: request.user_agent, 
													referrer: request.referrer, original_url: request.original_url }.merge(extras)
			end

	end
end