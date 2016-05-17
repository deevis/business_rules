puts "...controllers/rules/rules_controller_spec.rb"
require "spec_helper"

describe Rules::RulesController do
  
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

  describe "POST #create" do 
    it "responds successfully with a new Rule" do
      post :create, {rules_rule: {name:"Test", description:"Description"}}
      expect(assigns(:rules_rule).id).to be > 0
      expect(response.status).to eq(302)
    end
  end

  describe "GET #add_action_mapping" do 
    it "responds successfully with a new Rule" do
      r = Rules::RulesConfig.add_rule(
                {
                  name:"Test Rule 2", 
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
  end

  # describe "GET #lookup_events" do
  #   it "responds with an HTTP 200 status code" do 
  #     get :lookup_events
  #     puts response
  #   end
  # end

end