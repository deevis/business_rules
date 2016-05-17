require 'spec_helper'

describe "Rules::Handlers::WebRedirect" do 
	W = Rules::Handlers::WebRedirect

			# needs :service_url, :string
			# needs :service_method, :free_form, default: "GET", values: ["GET", "POST"] 
			# needs :content_type, :free_form, default: "", values: ["", "text/xml", "application/json"]
			
			# template :params  # merge fields created in here are used as the params for the call
			# template :headers # merge fields created in here are used as headers

			# needs :response_type, :free_form, default: "JSON", values: ["JSON", "XML", "TEXT"]


	it "can perform a WebRedirect" do 
		action = Rules::Action.new({ type: Rules::Handlers::WebRedirect,  
																		context_mapping: { "url:=>string" => '->{event[:wookie]}:=>free_form'}
																	})
		action.rule = Rules::Rule.new({id: "asdf"})
		h = W.new(action, {wookie: "cookie"})
		result = h.handle
		expect(result).to eq "cookie?redirect_rule_id=asdf"
		Rules::WebActionsQueue.get.first[:redirect_url].should eq "cookie?redirect_rule_id=asdf"
	end

	it "won't redirect if url_restrictions is populated and matches" do 
		action = Rules::Action.new({ type: Rules::Handlers::WebRedirect,  
																		context_mapping: { "url:=>string" => '->{event[:wookie]}:=>free_form',
																										"url_exceptions_regexp:=>string" => '/my_app/payout:=>free_form'}
																	})
		h = W.new(action, {wookie: "cookie", original_url: "/my_app/payout" } )
		result = h.handle
		expect(result).to eq :abort_action_chain
	end

	it "will redirect if url_restrictions is populated and doesn't match" do 
		action = Rules::Action.new({ type: Rules::Handlers::WebRedirect,  
																		context_mapping: { "url:=>string" => '/account?tab=commission_tab:=>free_form',
																										"url_exceptions_regexp:=>string" => '/my_app/payout:=>free_form'}
																	})
		action.rule = Rules::Rule.new({id: "asdf"})
		h = W.new(action, {original_url: "/another_url/that_doesnt_match" })
		result = h.handle
		expect(result).to eq "/account?tab=commission_tab&redirect_rule_id=asdf"
		Rules::WebActionsQueue.get.first[:redirect_url].should eq "/account?tab=commission_tab&redirect_rule_id=asdf"
	end

	it "can restrict redirects from a partial url regexp match" do 
		W.should_redirect?("/rules/submit_form", "submit_form").should eq false
	end

	it "can restrict redirects from a full url regexp match" do 
		W.should_redirect?("/rules/submit_form", "/rules/submit_form").should eq false
	end

	it "can restrict redirects from a partial url regexp match" do 
		W.should_redirect?("/rules/submit_form", "/rules/").should eq false
	end

	it "should always redirect without a from url or regexp_restriction" do 
		W.should_redirect?(nil, nil).should eq true
		W.should_redirect?("/rules/submit_form", nil).should eq true
		W.should_redirect?(nil, "asdf").should eq true
	end

	it "can restrict redirects from a multiple url regexp match" do 
		restrict_these = "submit|wookie"
		W.should_redirect?("/rules/submit_form", restrict_these).should eq false
		W.should_redirect?("/rules/wookie/my_form", restrict_these).should eq false
		W.should_redirect?("/rules/this_should_pass", restrict_these).should eq true
	end

	it "can restrict redirects from a multiple url regexp matches even if they are a bit malformed" do 
		restrict_these = "submit,wookie" # with a comma instead of a pipe
		W.should_redirect?("/rules/submit_form", restrict_these).should eq false
		W.should_redirect?("/rules/wookie/my_form", restrict_these).should eq false
		W.should_redirect?("/rules/this_should_pass", restrict_these).should eq true

		restrict_these = "submit, wookie" # with a comma and a space instead of a pipe
		W.should_redirect?("/rules/submit_form", restrict_these).should eq false
		W.should_redirect?("/rules/wookie/my_form", restrict_these).should eq false
		W.should_redirect?("/rules/this_should_pass", restrict_these).should eq true
	end

	it "won't redirect efforts to sign_out" do 
		W.should_redirect?("/rules/sign_out", nil).should eq false
	end

	it "won't redirect keep-alive (heartbeat) calls" do 
		W.should_redirect?("/rules/sign_out", nil).should eq false
	end

end