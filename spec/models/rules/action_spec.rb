puts "...models/rules/rule_spec.rb"
require 'models/rules/test_echo_handler'
require 'spec_helper'
require 'rules/handlers/base'

include Rules

describe Rules::Action do
  
  before(:each) do 
    Rules::Test.reset_instance_registry
    #puts("\n\nRules in the system:: #{Rules::Rule.count}")
  end

  describe "Actions will correctly expose the handler that they encapsulate" do 
		before(:each) do 
	  	@action = Action.new(title:"Test", active: true, type: "Rules::Handlers::WebAlert", template: {title: "My title", message: "My message"})
		end
	  
	  it "will have the right template names" do
	  	@action.template_names.size.should eq 2
	  end

	  it "will have the right template names" do
	  	@action.handler_class.should eq Rules::Handlers::WebAlert 
	  end

	  it "will have the right number of interpolated fields" do
	  	@action.template_fields(:message).size.should eq 0
	  end
	end

	describe "Actions with mapped fields that are no longer provided through the rule context will be dropped" do 
		before(:each) do 
			# Creating this @action with a Rule because some of our tests will be calling @action.save, which requires mongoid
			# to validate the Actions:
			#    embedded_in :rule, inverse_of: :actions
			#
			@rule = Rule.create(name: "Test rule", events: ["Rules::Test::ActiveDummy::create"])
			@rule.actions.create(title:"Test", active: true, type: "Rules::Handlers::WebAlert", 
															template: {"message" => "My {merge_1} field {merge_2}"},
															context_mapping: { "level:=>select" => "success:=>free_form",
																									"options:=>select" => "OK:=>free_form",
																									"merge_1:=>string" => "trigger.from_event_1:=>string",
																							 		"merge_2:=>string" => "trigger.from_event_2:=>string"		})
			@action = @rule.actions.first		
		end

		it "should drop merge_1 and merge_2 mappings when from_event_1 and from_event_2 are no longer reachable from Rule context" do 
			@action.context_mapping.keys.size.should eq 5
			@rule.events.clear
			@rule.save
			@action.context_mapping.keys.size.should eq 3  # level from needs
		end

	end


	describe "Actions with merge fields in their templates" do 
		before(:each) do 
			# Creating this @action with a Rule because some of our tests will be calling @action.save, which requires mongoid
			# to validate the Actions:
			#    embedded_in :rule, inverse_of: :actions
			#
			@rule = Rule.create(name: "Test rule", events: ["Rules::Test::ActiveDummy::create"])
			@rule.actions.create(title:"Test", active: true, type: "Rules::Handlers::WebAlert", 
															template: {"message" => "My {merge_1} field {merge_2}"},
															context_mapping: { "level:=>select" => "success:=>free_form",
																									"merge_1:=>string" => "trigger.from_event_1:=>string",
																							 		"merge_2:=>string" => "trigger.from_event_2:=>string"		})
			@action = @rule.actions.first		
		end
  

	  it "will have the correct number of merge fields identified" do
	  	@action.template_fields(:message).size.should eq 2
	  end

	  it "will remove context_mapping entries if merge fields are removed from the template" do
	  	@action.context_mapping["merge_2:=>string"].should_not be_nil
	  	@action.set_template("message", "My {merge_1} field")  # we are removing merge_2 from template["message"] by not including it here
	  	@action.save
	  	@action.context_mapping["merge_2:=>string"].should be_nil

	  end

	  it "will correctly merge values into the template" do 
	  	trigger = Hashie::Mash.new({from_event_1: "val1", from_event_2: "val2"})
	  	handler = @action.handler_class.new(@action, {trigger: trigger} 	)
	  	handler.eval_template(:message).should eq "My val1 field val2"
	  end

	  it "will only allow lowercase template_field names" do 
	  	# try to set the template with upper case field names
	  	@action.set_template("message", "My {Merge_1} field {Merge_2}")
	  	expect(@action.template_body("message")).to eq "My {merge_1} field {merge_2}"
	  end

	  it "will allow upper and lower case fields that will be interpolated" do 
	  	# try to set the template with upper case field names
	  	@action.set_template("message", "My {user.displayName}")
	  	expect(@action.template_body("message")).to eq "My {user.displayName}"
	  end



	  it "will convert to lowercase field names in templates and work with them through context_mapping" do
	  	trigger = Hashie::Mash.new({from_event_1: "val1", from_event_2: "val2"})
	  	# try to set the template with upper case field names
	  	@action.set_template("message", "My {Merge_1} field {Merge_2}")
	  	expect(@action.template_body("message")).to eq "My {merge_1} field {merge_2}"
	  	@action.context_mapping = { "level:=>select" => "success:=>free_form",
																									"merge_1:=>string" => "trigger.from_event_1:=>string",
																							 		"merge_2:=>string" => "trigger.from_event_2:=>string"		}
			@action.save																							 		
	  	handler = @action.handler_class.new(@action, {trigger: trigger} 	)
	  	handler.eval_template(:message).should eq "My val1 field val2"
	  end

	  it "will not report re-used template fields multiple times" do
	  	# Regression test for PYR-8072 DBH 1/23/2015
	  	trigger = Hashie::Mash.new({from_event_1: "val1", from_event_2: "val2"})
	  	# try to set the template with upper case field names
	  	@action.set_template("message", "My {Merge_1} field {Merge_2} and {Merge_2} again")
	  	expect(@action.template_body("message")).to eq "My {merge_1} field {merge_2} and {merge_2} again"
	  	@action.context_mapping = { "level:=>select" => "success:=>free_form",
																									"merge_1:=>string" => "trigger.from_event_1:=>string",
																							 		"merge_2:=>string" => "trigger.from_event_2:=>string"		}
			@action.save																							 		
	  	handler = @action.handler_class.new(@action, {trigger: trigger} 	)
	  	# Regression test for PYR-8072 - note that multiple fields don't result in #'s
	  	handler.eval_template(:message).should eq "My val1 field val2 and val2 again"
	  	@action.template_fields("message").size.should eq 2
	  end

	end


	describe "Actions will be ready?" do 
		before(:each) do 
			# Creating this @action with a Rule because some of our tests will be calling @action.save, which requires mongoid
			# to validate the Actions:
			#    embedded_in :rule, inverse_of: :actions
			#
			@rule = Rule.create(name: "Test rule", events: ["Rules::Test::ActiveDummy::create"])
			@rule.actions.create(title:"Test", active: true, type: "Rules::TestEchoHandler", 
															context_mapping: { "required_string:=>string" => "trigger.from_event_1:=>string" })
			@action = @rule.actions.first		
		end

		it "when all needs (even optional) are provided" do 
			@action.context_mapping["optional_string:=>string"] = "trigger.from_event_2:=>string"
			expect(@action.ready?).to eq true
		end

		it "when required needs are all provided" do 
			expect(@action.ready?).to eq true
		end

		it "unless a required need is missing" do 
			@action.context_mapping.delete("required_string:=>string")
			expect(@action.ready?).to eq false			
		end
	end  	
  	

end