module Rules
	class RulesActionAnalytics < ActiveRecord::Base

		@@object_views ||= Hash.new(0)	# Misses will return 0
		@@count=0

		DISALLOW_TRACKING_FOR = []
  	@@semaphore = Mutex.new

		# track that the action has been encountered by the system
		def self.track(action, rule_context)
			action_name = action.action_type
			return if Rules.disabled? || action_name.blank? || DISALLOW_TRACKING_FOR.index(action_name)
			begin
				# {"Rules::RulesActionAnalytics" => 7}		Item with id=3 has 7 views to update
				@@object_views[action_name] += 1
				Rules::Rule.publish_if_enabled  type: "action", name: action_name, rule_id: action.rule.id.to_s, 
							rule_context_guid: rule_context.context_guid
				@@count += 1
				write_views_to_db
			rescue => e
				puts "\n\nERROR\n#{e.message}\n\n"
			end	
		end

		def self.reset 
			@@object_views.clear 
		end

		def self.view_pending
			@@object_views.clone
		end

		def self.write_views_to_db(force = false)
			if (force || (@@count >= Rules.flush_rules_action_analytics_every))
     	 	write_these = nil
     	 	@@semaphore.synchronize do 
					return if (@@count < Rules.flush_rules_action_analytics_every)  # well, while we were blocked on the Mutex, someone else came and beat us to it - we'll just return then, shall we?
					@@count = 0
					write_these = @@object_views.clone
					@@object_views = Hash.new(0)
				end
				puts "Writing RulesActionAnalytics: #{write_these}"
				Thread.new {
						ActiveRecord::Base.connection_pool.with_connection do
							start = Time.now
							write_these.each do |action_name, count|
								begin
									raa = Rules::RulesActionAnalytics.where(action_name: action_name).first_or_create
									raa.count += count
									raa.save!
								rescue => e 
									puts "Error : #{e.message}"
								end
							end
							elapsed = Time.now - start
							puts "Updated #{write_these.keys.count} RulesActionAnalytics in #{elapsed} seconds"
						end
				}
			end
		end

	end
end
