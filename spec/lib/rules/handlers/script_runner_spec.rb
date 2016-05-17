require 'spec_helper'

			# template :code


describe 'Rules::Handlers::ScriptRunner' do 
	it 'can do simple arithmetic' do 
		action = Rules::Action.new({ type: Rules::Handlers::ScriptRunner,  
																		template: { "code" => "1 + 1" }
																	})
		h = Rules::Handlers::ScriptRunner.new(action, {})
		result = h.handle
		expect(result).to eq 2
	end

	it 'can access action_chain_results' do 
		action = Rules::Action.new({ type: Rules::Handlers::ScriptRunner,  
																		template: { "code" => "action_chain_results.last" }
																	})
		h = Rules::Handlers::ScriptRunner.new(action, {}, nil, ["last result on action chain"])	# last arg is action_chain_results
		result = h.handle
		expect(result).to eq "last result on action chain"
	end

	it 'can access activerecord date expressions' do 
		action = Rules::Action.new({ type: Rules::Handlers::ScriptRunner,  
																		template: { "code" => "5.days.ago.midnight" }
																	})
		h = Rules::Handlers::ScriptRunner.new(action, {})
		result = h.handle
		expect(result).to eq 5.days.ago.midnight
	end

	# it 'can check if a file exists' do 

	# 	action = Rules::Action.new({ type: Rules::Handlers::ScriptRunner,  
	# 																	template: { "code" => "1 + 1" }
	# 																})
	# 	h = Rules::Handlers::ScriptRunner.new({}, action)
	# 	result = h.handle
	# 	expect(result).to eq 2
	# end


end