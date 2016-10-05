require 'spec_helper'

class Rules::TestAction < Rules::Handlers::Base

	set_synchronous true

	def handle
	  super 
	end

end

class Rules::TestEvent

	def self.after_update(args);nil;end
	def self.after_create(args);end
	def self.before_destroy(args);end
	def changes;{"field"=>["before","after"], "updated_at"=>[1.hour.ago,1.minute.ago]};end

	include Rules::ModelEventEmitter		# Include afterwards cuz need mock methods above
end

def do_c_or_d_test
  c_d = Rules::Rule.import(
            {
              name:"When C or D is created, create an E but only if it was D that was created", 
              active: true,
              events: ["Rules::Test::C::create", "Rules::Test::D::create"], 
              criteria: "klazz == 'Rules::Test::D' && action == 'create'",
              actions: [
                  {
                    title: "Create E", type: Rules::Handlers::CreateModel,
                    context_mapping: {
                      "type:=>class_lookup" => "rules/test/e:=>class_lookup"
                    }
                  }
              ]
            }, overwrite: true)
  Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
  puts "#{Rules::Rule.count} Rules in system"
  Rules::Test::C.create
  expect( Rules::Test.instance_registry[Rules::Test::E].size).to eq 0
  Rules::Test::D.create
end

describe Rules::RulesEngine do

  before(:each) do 
    Rules::Test.reset_instance_registry
    #puts("\n\nRules in the system:: #{Rules::Rule.count}")
  end

	describe "Events" do 
		before :each do 
		  @rule = Rules::RulesConfig.add_rule(
            {
              name:"Test Rule", 
              event_inclusion: /Rules::TestEvent::create/, 
              criteria: "",
              action_configs: [
                  {
                    title: "Test Action", type: Rules::TestAction
                  }
              ]
            })
		end

		it "should have valid context for created event" do
			
		end
	end

  it "can reflect upon event_type and action in criteria"  do 
    do_c_or_d_test
    expect( Rules::Test.instance_registry[Rules::Test::E].size).to eq 1
  end

  it "won't run rules from inside with_rules_disabled blocks"  do 
    Rules.with_rules_disabled do 
      do_c_or_d_test
    end
    # Because we ran in a with_rules_disabled block, the rule should not have fired
    expect( Rules::Test.instance_registry[Rules::Test::E].size).to eq 0
  end

  it "can reflect upon event_type and action in criteria"  do 
    c_d = Rules::Rule.import(
              {
                name:"When C or D is created, create an E but only if it was D that was created", 
                active: true,
                events: ["Rules::Test::C::create", "Rules::Test::D::create"], 
                criteria: "klazz == 'Rules::Test::D' && action == 'create'",
                actions: [
                    {
                      title: "Create E", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/e:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)
    Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
    puts "#{Rules::Rule.count} Rules in system"
    Rules::Test::C.create
    expect( Rules::Test.instance_registry[Rules::Test::E].size).to eq 0
    Rules::Test::D.create
    expect( Rules::Test.instance_registry[Rules::Test::E].size).to eq 1
  end


  it "will not error out when run with invalid criteria" do
    r = Rules::Rule.import(
              {
                name:"This has bad criteria", 
                active: true,
                events: ["Rules::Test::C::create"], 
                criteria: "",
                actions: [
                    {
                      title: "Create D", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/d:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)
    # We cannot import with invalid criteria anymore
    r.criteria = "asdf"
    # So set this after the fact and then bypass validations
    r.save(validate: false)
    Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
    begin
      c = Rules::Test::C.create
    rescue => e 
      fail "We didn't want an exception to come back out"
    end
  end

  it "chained rules can create new models in sequence" do
    puts "\n\n ---chained rules can create new models in sequence---\n\n".upcase
    c_d = Rules::Rule.import(
              {
                name:"When C is created, create a D", 
                active: true,
                events: ["Rules::Test::C::create"], 
                criteria: "",
                actions: [
                    {
                      title: "Create D", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/d:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)
     d_e = Rules::Rule.import(
              {
                name:"When D is created, create a E", 
                active: true,
                events: ["Rules::Test::D::create"], 
                criteria: "",
                actions: [
                    {
                      title: "Create E", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/e:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)
    Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
    puts("\n\nRules in the system:: #{Rules::Rule.count}")
    puts "\n\nB4 create: #{Rules::Test.instance_registry}\n\n"
    c = Rules::Test::C.create
    puts "\n\nAfter create: #{Rules::Test.instance_registry}\n\n"
    expect( Rules::Test.instance_registry[Rules::Test::C].size).to eq 1
    # the fact that we created A should have triggered a_b and now there should be a B instance
    expect( Rules::Test.instance_registry[Rules::Test::D].size).to eq 1
    # the fact that a_b created B should have triggered b_c and now there should be a C instance
    expect( Rules::Test.instance_registry[Rules::Test::E].size).to eq 1
  end


  it "rules can create new models" do
    puts "\n\n ---rules can create new models---\n\n".upcase

    a_b = Rules::Rule.import(
              {
                name:"A creates B", 
                active: true,
                events: ["Rules::Test::A::create"], 
                criteria: "",
                actions: [
                    {
                      title: "Create B", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/b:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)
    Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
    puts "\n\nB4 create: #{Rules::Test.instance_registry}\n\n"
    a = Rules::Test::A.create
    puts "\n\nAfter create: #{Rules::Test.instance_registry}\n\n"
    expect( Rules::Test.instance_registry[Rules::Test::A].size).to eq 1
    # the fact that we created A should have triggered a_b and now there should be a B instance
    expect( Rules::Test.instance_registry[Rules::Test::B].size).to eq 1
  end


  it "chained rules with cycles will short-circuit when they become re-entrant" do
    a_b = Rules::Rule.import(
              {
                name:"When A is created, create a B", 
                active: true,
                events: ["Rules::Test::A::create"], 
                criteria: "",
                actions: [
                    {
                      title: "Create B", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/b:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)
     b_c = Rules::Rule.import(
              {
                name:"When B is created, create a C", 
                active: true,
                events: ["Rules::Test::B::create"], 
                criteria: "",
                actions: [
                    {
                      title: "Create C", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/c:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)
 
     c_a = Rules::Rule.import(
              {
                name:"When C is created, create a A", 
                active: true,
                events: ["Rules::Test::C::create"], 
                criteria: "",
                actions: [
                    {
                      title: "Create A", type: Rules::Handlers::CreateModel,
                      context_mapping: {
                        "type:=>class_lookup" => "rules/test/a:=>class_lookup"
                      }
                    }
                ]
              }, overwrite: true)

    Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
    puts Rules::Test.instance_registry
    a = Rules::Test::A.create
    puts Rules::Test.instance_registry
     # the fact that we created A should have triggered a_b and now there should be a B instance
    expect( Rules::Test.instance_registry[Rules::Test::B].size).to eq 1
    # the fact that a_b created B should have triggered b_c and now there should be a C instance
    expect( Rules::Test.instance_registry[Rules::Test::C].size).to eq 1
    # then, since C was created, c_a should have fired and created the second A
    expect( Rules::Test.instance_registry[Rules::Test::A].size).to eq 2
    # and lastly, since A was created, a_b should have tried to fire again but been rejected as re-entrant
  end

  it "will not respect display_priority when multiple WebAlerts are rendered via same Thread" do
    rules_created = []
    6.times do |x|
      display_priority = (x%3 == 2) ? "first" : "normal"  # make every 3rd rule "first"
      rules_created << Rules::Rule.import(
              {
                name:"Normal Priority WebAlert #{x}", 
                active: true,
                events: ["Rules::Test::C::create"], 
                criteria: "true",
                actions: [
                    {
                      title: "Create WebAlert", type: Rules::Handlers::WebAlert,
                      template: {"message" => "Normal WebAlert"},
                      context_mapping: {
                        "level:=>select" => "success:=>free_form",
                        "display_priority:=>select" => "#{display_priority}:=>free_form"
                      }
                    }
                ]
              }, overwrite: true)
    end

    Rules::RulesEngine.reload_configuration  # Do this or you'll get silly race-condition-like problems!
    begin
      c = Rules::Test::C.create
      # so - both rules should have fired, but regardless of the order, we should find
      # "First Priority WebAlert" as the first in the web_actions_queue
      web_actions_queue = Thread.current[:rules_web_actions_queue]
      web_actions_queue.size.should eq rules_created.size
      # make sure that no "normal" becomes any "first"
      normal_found = false
      priority_list = web_actions_queue.map{|a| a[:rules_popup_display_priority]}
      priority_list.each do |dp|
        if normal_found && dp == 'first'
          fail "WebAlert ordering failed: found a 'normal' display priority WebAlert before a 'first' : #{priority_list}" 
        end
        normal_found |= (dp == 'normal')
      end
    end
  end


end