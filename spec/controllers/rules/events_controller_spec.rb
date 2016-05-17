puts "...controllers/rules/events_controller_spec.rb"
require 'models/rules/test_echo_handler'
require "spec_helper"

describe Rules::EventsController do
  
  describe "GET #index" do
    it "responds successfully with an HTTP 200 status code" do
      get :index
      expect(response).to be_success
      expect(response.status).to eq(200)
    end

    it "renders the index template" do
      get :index
      expect(response).to render_template("index")
    end
  end

  it "renders the show template" do
    expected = {"context"=>
      {"system"=>"messaging_user",
       "actor"=>"user",
       "klazz"=>"string",
       "trigger"=>"futureaction"},
     "actions"=>["create", "update", "delete"], "type" => "ModelEvent" 
   }

    get :show, id: "Rules::FutureAction::create", format: :json
    json = JSON.parse(response.body)
    expect(json).to eq expected
  end

  
  describe "push_event" do 

    it "Can push DynamicEvents" do 
      event_name = "blah::eek::action_type"
      event_hash = { event: event_name}
      post :push_event, event_hash, format: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to eq true
      expect(json["message"]).to eq nil
      expect(json["event"]).to eq event_name
      expect(json["type"]).to eq "DynamicEvent"
    end


    describe "ModelEvents" do 

      it "can push an event referencing an existing object" do 
        fa = Rules::FutureAction.create(priority: 75) 
        params = { event: "Rules::FutureAction::create", 
              trigger_id: fa.id,
                    data: fa.attributes.clone }
        post :push_event, params, format: :json
        json = JSON.parse(response.body)
        expect(json["success"]).to eq true
        expect(json["klazz"]).to eq "Rules::FutureAction"
        expect(json["action"]).to eq "create"
        expect(json["type"]).to eq "ModelEvent"
      end

      describe "will cause rules to run" do 

        it "with id passed explicitly" do 
          fa = Rules::FutureAction.create(priority: 75) 
          Thread.current[:echo_handler_required_string] = nil 
          r = Rules::Rule.create(name: "Test Dynamic Rule", events: ["Rules::FutureAction::create"],
                                    criteria: "trigger.priority == 75")
          r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
                                    context_mapping: { "required_string:=>string" => "trigger.priority:=>integer" })
          Rules::RulesEngine.reload_configuration

          params = { event: "Rules::FutureAction::create", 
                trigger_id: fa.id,
                      data: fa.attributes.clone }
          post :push_event, params, format: :json
          json = JSON.parse(response.body)
          
          expect(json["success"]).to eq true
          expect(json["klazz"]).to eq "Rules::FutureAction"
          expect(json["action"]).to eq "create"
          expect(json["type"]).to eq "ModelEvent"

          expect(Thread.current[:echo_handler_required_string]).to eq 75
        end


        describe "without trigger_id passed explicitly" do 
          it "can still run rules" do 
            fa = Rules::FutureAction.create(priority: 75) 
            Thread.current[:echo_handler_required_string] = nil 
            r = Rules::Rule.create(name: "Test Dynamic Rule", events: ["Rules::FutureAction::create"],
                                      criteria: "trigger.priority == 75")
            r.actions.create( title: "Test Echo Handler", type: Rules::TestEchoHandler, 
                                      context_mapping: { "required_string:=>string" => "trigger.priority:=>integer" })
            Rules::RulesEngine.reload_configuration

            params = { event: "Rules::FutureAction::create", 
                        data: fa.attributes.clone }
            post :push_event, params, format: :json
            json = JSON.parse(response.body)
            
            expect(json["success"]).to eq true
            expect(json["klazz"]).to eq "Rules::FutureAction"
            expect(json["action"]).to eq "create"
            expect(json["type"]).to eq "ModelEvent"

            expect(Thread.current[:echo_handler_required_string]).to eq 75
          end 

          it "can run rules AND subsequently UPDATE the implied trigger that is not actually loaded from the DB initially" do 
            fa = Rules::FutureAction.create(priority: 75) 
            r = Rules::Rule.create(name: "Test Dynamic Rule", events: ["Rules::FutureAction::create"],
                                      criteria: "trigger.priority == 75")
            r.actions.create( title: "Update run_at time", type: Rules::Handlers::ScriptRunner, 
                                      template: { "code" => "trigger.run_at=Time.now;trigger.save!" })
            Rules::RulesEngine.reload_configuration

            params = { event: "Rules::FutureAction::create", 
                        data: fa.attributes.clone }

            expect(fa.run_at.to_i).to eq 0 

            post :push_event, params, format: :json
            json = JSON.parse(response.body)
            
            expect(json["success"]).to eq true
            expect(json["klazz"]).to eq "Rules::FutureAction"
            expect(json["action"]).to eq "create"
            expect(json["type"]).to eq "ModelEvent"
            fa.reload 
            expect(fa.run_at.to_i).to be > 0 

          end

          it "can run rules and reference :changes when accessing the implied trigger" do 
            fa = Rules::FutureAction.create(priority: 75) 
            r = Rules::Rule.create(name: "Test Dynamic Rule", events: ["Rules::FutureAction::update"],
                  criteria: "trigger.priority == 75 && changes['priority'] && changes['priority'][0] == 50")
            r.actions.create( title: "Update run_at time", type: Rules::Handlers::ScriptRunner, 
                                      template: { "code" => "trigger.run_at=Time.now;trigger.save!" })
            Rules::RulesEngine.reload_configuration

            params = { event: "Rules::FutureAction::update", 
                        data: fa.attributes.clone,
                        changes: { priority: [50,75] } }

            expect(fa.run_at.to_i).to eq 0 

            post :push_event, params, format: :json
            json = JSON.parse(response.body)
            
            expect(json["success"]).to eq true
            expect(json["klazz"]).to eq "Rules::FutureAction"
            expect(json["action"]).to eq "update"
            expect(json["type"]).to eq "ModelEvent"
            fa.reload 
            expect(fa.run_at.to_i).to be > 0 

          end

        end
      end
    end
  end

end