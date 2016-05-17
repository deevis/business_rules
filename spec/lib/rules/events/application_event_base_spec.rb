require 'spec_helper'
require 'rules/events/application_event_base'

class TestEvent < Rules::Events::ApplicationEventBase 
  def trigger_class; Rules::Test::A; end
end

class TestEventB < Rules::Events::ApplicationEventBase 
  def trigger_class; Rules::Test::B; end
end

describe Rules::Events::ApplicationEventBase do 

  it "can raise events of one type" do 
    a = Rules::Test::A.create
    event_hash = TestEvent.new.raise_event(a, {mydata: "myvalue"})
    event_hash.should eq({type: "ApplicationEvent", user: nil, processing_stack: [], 
                        klazz: "TestEvent", id: a.id, mydata: "myvalue",
                        action: "raised"})
  end

  it "can raise events of another type" do 
    b = Rules::Test::B.create
    event_hash = TestEventB.new.raise_event(b, {mydata: "myvalue"})
    event_hash.should eq({type: "ApplicationEvent", user: nil, processing_stack: [], 
                        klazz: "TestEventB", id: b.id, mydata: "myvalue",
                        action: "raised"})
  end

  it "will fail when trigger is the wrong type" do 
    event_hash = TestEvent.new.raise_event(Rules::Test::B.create, {mydata: "myvalue"})
    event_hash.should eq nil 
  end

  it "will fail with Exception when trigger is the wrong type and raise_event! is called" do 
    expect {TestEvent.new.raise_event!(Rules::Test::B.create, {mydata: "myvalue"})}.to raise_exception
    
  end

  it "will find application events in the RulesConfig dictionary" do 
    Rules::RulesEngine.reload_configuration 
    cfg1 = Rules::RulesConfig.event_config("TestEvent") 
    expect(cfg1.blank?).to_not eq true
    cfgb = Rules::RulesConfig.event_config("TestEventB") 
    expect(cfgb.blank?).to_not eq true
  end
end