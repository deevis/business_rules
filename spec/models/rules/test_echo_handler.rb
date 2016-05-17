require 'rules/handlers/base'

class Rules::TestEchoHandler < Rules::Handlers::Base

	needs :required_string, :string 	
	needs :optional_string, :string, optional: true
	
	def handle
		puts "\n\nRules::TestEchoHandler fired\n\n#{required_string}\n\n\n\n"
	end

end