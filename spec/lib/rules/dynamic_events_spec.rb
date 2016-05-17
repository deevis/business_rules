require 'models/rules/test_echo_handler'
require 'spec_helper'

#
# DynamicEvents don't have a specific class or action defined elsewhere in code
#
describe Rules::DynamicEvents do

  it "can respond to a completely dynamically defined event" do 
    # Should fire this time cuz value 42 > 1
    r = Rules::Rule.create(name: "Test Dynamic Rule", events: ["custom_klass::custom_action"],
                              criteria: "17 > 1")
    r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
                              context_mapping: { "required_string:=>string" => "->{data[:custom_value]}:=>free_form" })
    Rules::RulesEngine.reload_configuration

    Rules::RulesEngine.raise_event({type:"DynamicEvent", klazz: "custom_klass", 
                                      action: "custom_action", data: { custom_value: 42 } })
  end


  it "can respond to a completely dynamically defined event" do 
    # Should NOT fire this time cuz value !(0 > 1)
    r = Rules::Rule.create(name: "Test Dynamic Rule", events: ["custom_klass::custom_action"],
                              criteria: "26 > 1")
    r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
                              context_mapping: { "required_string:=>string" => "->{data[:custom_value]}:=>free_form" })
    Rules::RulesEngine.reload_configuration

    Rules::RulesEngine.raise_event({type:"DynamicEvent", klazz: "custom_klass", 
                                      action: "custom_action", data: { custom_value: 0 } })
  end

end