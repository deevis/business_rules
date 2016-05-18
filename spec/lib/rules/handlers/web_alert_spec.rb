require 'spec_helper'

describe "Rules::Handlers::WebAlert" do 

      # set_synchronous true
      # set_testable true

      # needs :level, :select, default: "info", values: ["info", "primary", "success", "warning", "danger"]
      # template :title
      # template :message


  it "can perform a WebAlert" do 
    action = Rules::Action.new({ type: Rules::Handlers::WebAlert,  
                                    context_mapping: { "level:=>select" => "success:=>free_form"},
                                    template: {"title" => "My title", 
                                              "message" => "My message"}
                                  })
    h = Rules::Handlers::WebAlert.new(action, {})
    result = h.handle
    action = Rules::WebActionsQueue.get.first
    action[:rules_popup_level].should eq "success"
    action[:rules_popup_title].should eq "My title"
    action[:rules_popup_message].should eq "My message"
  end

  describe "action state" do 
    before(:each) do 
      @action = Rules::Action.new({ type: Rules::Handlers::WebAlert,  
                                    context_mapping: { "level:=>select" => "success:=>free_form"},
                                    template: {"title" => "My title", 
                                             "message" => "My message"}
                                    })
    end

    it "will be marked synchronous" do 
      @action.synchronous?.should eq true
    end

    it "cannot be scheduled" do 
      @action.can_be_scheduled?.should eq false
    end

    it "cannot defer processing" do 
      @action.can_defer_processing?.should eq false
    end

    it "will be marked testable" do 
      @action.testable?.should eq true
    end

  end      

  it "will not perform a WebAlert when template[title] is tombstoned" do 
    action = Rules::Action.new({ type: Rules::Handlers::WebAlert,  
                                    template: {"title" => ":rip", 
                                              "message" => "My message"}
                                  })
    h = Rules::Handlers::WebAlert.new(action, {})
    result = h.handle
    Thread.current[:rules_popup_title].should eq nil
    Thread.current[:rules_popup_message].should eq nil
  end

end



