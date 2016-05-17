require 'spec_helper'
require 'rules/events/application_event_base'

class TestEvent < Rules::Events::ApplicationEventBase 
  set_trigger_class Rules::Test::A 
end

describe Rules::Events::ApplicationEventBase do 

  it "can raise events" do 
    event_hash = TestEvent.new.raise_event(Rules::Test::A.create, {mydata: "myvalue"})
    event_hash.should eq({type: "TestEvent", user: nil, processing_stack: [], 
                        klazz: "Rules::Test::A", id: 1, mydata: "myvalue",
                        action: "system"})
  end

end