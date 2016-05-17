module Rules
	module Handlers
		module MessagingRecipientEmitter

			def self.included(base) 
				base.send	:needs, :recipient, :messaging_user
			end


			def _handle
	      @recipients = [recipient].flatten
	      if @recipients.count > 0 
	        @recipients.each do |r|
	          begin
	          	set_default_market(r)
	          	for_recipient(r)
	          rescue => e 
	          	puts "Error "
	          	puts e.message
	          	puts e.backtrace
	          	return false
	          ensure
	          	clear_default_market
	          end
	        end
	      end
	      return unified_result
			end

			def unified_result
				# eg: return a single Message instead of all the individual MessageRecipients
				@recipients
			end

		end
	end
end