module Rules
	module Handlers
		class ScriptRunner < Rules::Handlers::Base

			template :code 

			

			@@restricted_words = %w(sudo destroy delete mysql)

			def _handle
				code_to_run = eval_template(:code)
				@@restricted_words.each do |rw| 
					if code_to_run.downcase.index(rw)
						puts "Not running ScriptRunner\n-------------------------------------\n#{code_to_run}\n\nCannot run code containing restricted word [#{rw}]\n"
						raise "Cannot run code containing restricted word [#{rw}]"
					end
				end
				result = eval(code_to_run)
				puts "    DEBUG: Script evaluated to [#{result}]"
				return result
			rescue => e 
				puts e.message
				puts e.backtrace
				return false
			end

		end
	end
end