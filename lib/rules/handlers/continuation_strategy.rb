module Rules
	module Handlers
		module ContinuationStrategy

			@@registered_strategies = []

			def self.included(base)
				@@registered_strategies << base if !registered_strategies.index(base)				
				base.class_eval do 
					class_attribute :title, :icon, :trigger, :criteria

					def self.set_title(value=nil)
						self.title = value if value
					end

					def self.set_icon(value=nil)
						self.icon = value if value
					end

					def self.set_trigger(value=nil)
						self.trigger = value if value
					end

					def self.set_criteria(value=nil)
						self.criteria = value if value
					end

					def self.process_rule(event, deferred_action_chain = nil, extras = {})
						criteria_passes = false
						if (event_criteria = criteria[:event])
							criteria_passes = event.instance_eval(event_criteria) rescue nil
						end
						if (criteria_passes)
							# Check that the event has an ActionChainStep which is waiting on it
							acs = Rules::ActionChainStep.where( waiting_on_type: event[:klazz], waiting_on_id: event[:id]).first
							if acs 
								acs.continue
							end
						end
					end
				end
			end
			
			def self.registered_strategies
				@@registered_strategies
			end


		end
	end
end