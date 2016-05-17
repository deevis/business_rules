module Rules
	class EventSubscriber

		def initialize
		end

		def connect 
			host, port = APP_CONFIG[:redis_server].split(":")
			@redis = Redis.new(host: host, port: port)
			begin
			  @redis.subscribe( "rules_events" ) do |on|
			    on.subscribe do |channel, subscriptions|
			      puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
			    end

			    on.message do |channel, message|
			      puts "##{channel}: #{message}"
			      @redis.unsubscribe if message == "exit"
			    end

			    on.unsubscribe do |channel, subscriptions|
			      puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
			    end
			  end
			rescue Redis::BaseConnectionError => error
			  puts "#{error}, retrying in 1s"
			  sleep 1
			  retry
			end
		end

		def disconnect 
			@redis.unsubscribe
		end

	end
end