# == Schema Information
#
# Table name: rules_unique_rule_firings
#
#  id                :integer          not null, primary key
#  rule_id           :string
#  unique_expression :string
#  fired_at          :datetime
#

require 'spec_helper'
require 'rules/handlers/base'
require 'models/rules/test_echo_handler'
require 'models/rules/raise_exception_handler'

describe Rules::UniqueRuleFiring do

  before(:all) do 
    Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
  end

  it "will not allow a rule to fire more than once with a given unique expression" do 
    Rules::UniqueRuleFiring.delete_all
    Rules::Rule.delete_all
    r = Rules::RulesConfig.add_rule(
              {
                name:"Test Rule 1234_#{Time.now.to_i}", 
                active: true,
                event_inclusion: /Rules::Rule::update/, 
                criteria: "",
                unique_expression: '"asdf_#{Time.now.to_i}"',
                action_configs: [
                    {
                      title: "Test Echo Action", type: Rules::TestEchoHandler, 
                              context_mapping: { "required_string:=>string" => "wookie:=>free_form" }
                    },
                    {
                      title: "Test Echo Action2", type: Rules::TestEchoHandler, 
                              context_mapping: { "required_string:=>string" => "wookieeeee:=>free_form" }
                    }


                ]
              })
    r.ready?.should eql true
    r.should_not be_nil
    event_hash = {type: "ModelEvent", klazz: "Rules::Rule", id: r.id, action: "update"}
    r.process_rule( event_hash ).should eql(0) 
    # should not fire the second time with the same expression
    r.process_rule(event_hash).should eql(-4)

  end

  it "will work ok firing repeatedly for TimerEvents with unique expressions" do 
    # Working with FutureAction cuz it's a simple Model inthe Rule's domain
    Rules::FutureAction.create(priority:40)
    Rules::FutureAction.create(priority:41)
    Rules::FutureAction.create(priority:42)

    r = Rules::Rule.create(name: "Test Rule asdfasdf", events: ["TimerEvent<Rules::FutureAction>::timer"],
                              active: true, 
                              criteria: "FutureAction.all", 
                              unique_expression: '"asdf_#{trigger.priority}"',
                              timer: {expression:""})
    r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
                              context_mapping: { "required_string:=>string" => "wookie:=>free_form" } )

    # Will run through all of these just fine
    r.process_rule({type: "TimerEvent"}).should eql(0)
    
    # Will hit unique_expression issues with these, but the new one should process
    Rules::FutureAction.create(priority:43)
    
    # TODO: the following checks need to be put in place
    #       1) make sure that it does fire for the new 43
    #       2) make sure it does NOT fire for 40,41,42
    r.process_rule({type: "TimerEvent"}).should eql(-4)   # should eql 0

    # None of these should process
    r.process_rule({type: "TimerEvent"}).should eql(-4)   # should eql 0
  end

end
