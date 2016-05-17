module Rules
	class Analytics

		@@data = {}

		def self.track(&block)
			begin
				start_time = Time.now
				yield

			ensure
				Time.now - start_time

			end
		end

	end
end