require 'models/rules/test_echo_handler'
require 'spec_helper'

def fire_timer_event
	Rules::RulesEngine.raise_event({klazz: "TimerEvent", action: "tick", type: "TimerEvent" })
end

describe Rules::TimerEvents do
	
	before(:each) do  
		puts "Resetting ActionAnalytics..."
		Rules::RulesActionAnalytics.reset
		puts "Clearing Rules..."
		Rules::Rule.destroy_all
	end

	it "TimerEvents cause rules mapped to TimerEvent<klazz>::timer to fire" do
	  r = Rules::Rule.create(name: "Test Rule", events: ["TimerEvent<Rules::FutureAction>::timer"],
	  													criteria: "[1]")
	  r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
															context_mapping: { "required_string:=>string" => "wookie:=>free_form" })
	  Rules::RulesEngine.reload_configuration
	  Rules::FutureAction.create(priority:42)
	  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0
	  sleep(0.1)
	  fire_timer_event
	  sleep(0.25)
	  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 1
	  sleep(0.1)
	  fire_timer_event
	  sleep(0.25)
	  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 2
	end

	it "TimerEvents that return no TriggerItems will not cause any Actions to fire" do 
	  r = Rules::Rule.create(name: "Test Rule", events: ["TimerEvent<Rules::FutureAction>::timer"],
	  													criteria: "", 
	  													timer: {expression:""})
	  r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
															context_mapping: { "required_string:=>string" => "wookie:=>free_form" })
	  Rules::RulesEngine.reload_configuration
	  # This time, do not create a FutureAction to be returned
	  #Rules::FutureAction.create(priority:42)
	  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0
	  sleep(0.1)
	  fire_timer_event
	  sleep(0.25)
	  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0
	  sleep(0.1)
	  fire_timer_event
	  sleep(0.25)
	  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0

	end


	describe "TimerEvents with criteria" do
		# For these tests, FutureActions with priority 42 will fire
		before(:each) do 
		  r = Rules::Rule.create(name: "Test Rule", events: ["TimerEvent<Rules::FutureAction>::timer"],
		  													criteria: "FutureAction.where('priority = 42')",
		  													timer: {expression: ""})
	  	r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
															context_mapping: { "required_string:=>string" => "wookie:=>free_form" }) 
		  Rules::RulesEngine.reload_configuration
		end
		it "will fire Actions when criteria hit" do
		  Rules::FutureAction.create(priority:42)
		  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0
		  sleep(0.1)
		  fire_timer_event
		  sleep(0.25)
		  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 1
		end

		it "will not fire Actions when criteria miss" do
		  Rules::FutureAction.create(priority:69)
		  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0
		  sleep(0.1)
		  fire_timer_event
		  sleep(0.25)
		  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0
		end

		it "will fire Actions for each matched criteria object" do 
			# Create 3 FutureActions with priority 42
		  Rules::FutureAction.create(priority:42)
		  Rules::FutureAction.create(priority:42)
		  Rules::FutureAction.create(priority:42)
		  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 0
		  sleep(0.1)
		  fire_timer_event
		  sleep(0.25)
		  # Since we created 3 FutureActions with priority 42, it should have fired an action for each of them
		  expect(Rules::RulesActionAnalytics.view_pending["Rules::TestEchoHandler"]).to eq 3 
		end


	end



end