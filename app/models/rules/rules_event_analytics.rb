module Rules
	class RulesEventAnalytics < ActiveRecord::Base

		@@object_views ||= Hash.new(0)	# Misses will return 0
		@@count=0

		DISALLOW_TRACKING_FOR = ["Rules::RulesEventAnalytics::create", "Rules::RulesEventAnalytics::update", 
														"Rules::RulesActionAnalytics::create", "Rules::RulesActionAnalytics::update","TimerEvent"]
  	@@semaphore = Mutex.new

		# track that the event has been encountered by the system
		def self.track(event_payload)
			event_name = "#{event_payload[:klazz]}::#{event_payload[:action]}"
			return if Rules.disabled? ||  event_name.blank? || DISALLOW_TRACKING_FOR.index(event_name)
			begin
				@@object_views[event_name] += 1
				@@count += 1
				if Rules.rule_activity_channel_enabled && Rules.rule_activity_channel 
					case event_payload[:type]
					when "ControllerEvent"
						data = event_payload[:data].to_s
					when "ModelEvent"
						data = event_payload[:data].attributes
					end
					Rules::Rule.publish_if_enabled type: "event", name: event_name, params: data
				end
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
			if (force || (@@count >= Rules.flush_rules_event_analytics_every))
     	 	write_these = nil
     	 	@@semaphore.synchronize do 
					return if (@@count < Rules.flush_rules_event_analytics_every)  # well, while we were blocked on the Mutex, someone else came and beat us to it - we'll just return then, shall we?
					@@count = 0
					write_these = @@object_views.clone
					@@object_views = Hash.new(0)
				end
				puts "Writing RulesEventAnalytics: #{write_these}"
				Thread.new {
						ActiveRecord::Base.connection_pool.with_connection do
							start = Time.now
							write_these.each do |event_name, count|
								begin
									rea = Rules::RulesEventAnalytics.where(event_name: event_name).first_or_create
									rea.count += count
									rea.save!
								rescue => e 
									puts "Error : #{e.message}"
								end
							end
							elapsed = Time.now - start
							puts "Updated #{write_these.keys.count} RulesEventAnalytics in #{elapsed} seconds"
						end
				}
			end
		end
	end


end
