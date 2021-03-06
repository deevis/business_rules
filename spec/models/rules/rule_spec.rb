puts "...models/rules/rule_spec.rb"
require 'spec_helper'
require 'rules/handlers/base'
require 'models/rules/test_echo_handler'

describe Rules::Rule do
  
  before(:each) do 
    Rules::Test.reset_instance_registry
    #puts("\n\nRules in the system:: #{Rules::Rule.count}")
  end

  it "can initialize" do
    d = Rules::EventConfigLoader.events_dictionary
    expect(d.size).to be >= 1
  end 

  it "will have events available" do
    l = Rules::EventConfigLoader.events_list
    expect(l.size).to be >= 1
  end

  it "will have action_handlers available" do
    c = Rules::Handlers::Base.reload_configuration
    expect(c.size).to be >= 1
  end

  it "will detect valid context paths exposed via expose_rules_field" do 
    r = Rules::Rule.create(name: "Test Rule", events: ["Rules::Test::ActiveDummy::create"]) 
    r.validate_context_path("trigger.from_event_1").should eq true
  end

  it "can create a new persistent rule" do
    r = Rules::RulesConfig.add_rule(
              {
                name:"Test Rule", 
                event_inclusion: /Rules::Rule::create/, 
                criteria: "",
                action_configs: [
                    {
                      title: "Test Echo Action", type: Rules::TestEchoHandler
                    }
                ]
              })
    r.should_not be_nil
  end


  it "will not fire deleted rules" do
    r = Rules::RulesConfig.add_rule(
              {
                name:"Test Rule 2", 
                deleted: true,
                event_inclusion: /Rules::Rule::create/, 
                criteria: "",
                action_configs: [
                    {
                      title: "Test Echo Action", type: Rules::TestEchoHandler
                    }
                ]
              })
    r.should_not be_nil
    r.process_rule({}).should eql(-1)
  end

  it "will not fire inactive rules" do
    r = Rules::RulesConfig.add_rule(
              {
                name:"Test Rule 2", 
                active: false,
                event_inclusion: /Rules::Rule::create/, 
                criteria: "",
                action_configs: [
                    {
                      title: "Test Echo Action", type: Rules::TestEchoHandler
                    }
                ]
              })
    r.should_not be_nil
    r.process_rule({}).should eql(-2)
  end



  it "will not fire rules unless they are ready? (think missing action mappings)" do
    r = Rules::RulesConfig.add_rule(
              {
                name:"Test Rule 3", 
                active: true,
                event_inclusion: /Rules::Rule::create/, 
                criteria: "",
                action_configs: [
                    {
                      title: "Test Echo Action", type: Rules::Handlers::WebRedirect  # This needs mappings which we don't provide here on purpose
                    }
                ]
              })
    r.should_not be_nil
    r.process_rule({}).should eql(-5)
  end

  it "can export rules" do
    Rules::RulesConfig.add_rule(
              {
                name:"Test Rule 4", 
                active: true,
                event_inclusion: /Rules::Rule::create/, 
                criteria: "",
                action_configs: [
                    {
                      title: "Test Echo Action", type: Rules::TestEchoHandler
                    }
                ]
              })
  end

  it "can export rules" do
    Rules::RulesConfig.add_rule(
              {
                name:"Test Rule 5", 
                active: true,
                event_inclusion: /Rules::Rule::create/, 
                criteria: "",
                action_configs: [
                    {
                      title: "Test Echo Action", type: Rules::TestEchoHandler
                    }
                ]
              }).export
  end



  it "can import rules with Future Actions enabled" do 
     
    config = YAML.load_file( "spec/support/test_rule_import_future_actions.yaml") 
    config.should_not be nil
    r = Rules::Rule.import( config )
    r.actions.size.should eq 1 
    expect(r.actions.first.future_configuration[:run_at_expression]).to eq "Time.now + 1.day"
    expect(r.actions.first.future_configuration[:contingent_script]).to eq "trigger != nil"

  end

  describe "lookup_path" do 
    it "can reflect upon ModelEvents as triggers" do 
      r = Rules::RulesConfig.add_rule(
                {
                  name:"Test Rule 35", 
                  active: true,
                  event_inclusion: /Rules::Rule::create/, 
                  criteria: "",
                  action_configs: [
                      {
                        title: "Test Echo Action", type: Rules::TestEchoHandler
                      }
                  ]
                })
      path = r.lookup_path("trigger") 

      expect(path).to eq ( {   _id: :"bson::objectid",
                             c_at: :time,
                             u_at: :time,
                             version: :integer,
                             updated_by: :string,
                             updated_action: :string,
                             was_valid: :"mongoid::boolean",
                             name: :string,
                             synchronous: :"mongoid::boolean",
                             definition_file: :string,
                             description: :string,
                             events: :array,
                             category: :string,
                             criteria: :string,
                             active: :"mongoid::boolean",
                             unique_expression: :string,
                             _deleted: :"mongoid::boolean",
                             start_date: :time,
                             end_date: :time,
                             timer: :hash,
                             timer_expression: :string,
                             event_inclusion_matcher: :regexp,
                             event_exclusion_matcher: :regexp,
                             actions_hashed: :string })

    end

    it "can reflect upon SystemEvent-triggers" do 
      class TestEventTrigger < Rules::Events::ApplicationEventBase 
        def trigger_class; Rules::FutureAction; end 
      end

      Rules::RulesEngine.reload_configuration

      r = Rules::RulesConfig.add_rule(
                {
                  name:"Test Rule 35", 
                  active: true,
                  event_inclusion: /TestEventTrigger/, 
                  criteria: "",
                  action_configs: [
                      {
                        title: "Test Echo Action", type: Rules::TestEchoHandler
                      }
                  ]
                })
      path = r.lookup_path("trigger") 

      expect(path).to eq ( {:id=>:integer, :run_at=>:datetime, :contingent_script=>:string, 
                          :run_at_expression=>:string, :unique_expression=>:string, 
                          :recurring_expression=>:string, :rule_id=>:string, :action_id=>:string, 
                          :action_handler=>:string, :context_mapping=>:string, :template=>:string, 
                          :event=>:text, :created_at=>:datetime, :updated_at=>:datetime, 
                          :priority=>:integer, :unique_id=>:string, :processed_at=>:datetime } ) 

    end

  end
end