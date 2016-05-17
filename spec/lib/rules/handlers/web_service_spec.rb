require 'spec_helper'

describe "Rules::Handlers::WebService" do 

			# needs :service_url, :string
			# needs :service_method, :free_form, default: "GET", values: ["GET", "POST"] 
			# needs :content_type, :free_form, default: "", values: ["", "text/xml", "application/json"]
			
			# template :params  # merge fields created in here are used as the params for the call
			# template :headers # merge fields created in here are used as headers

			# needs :response_type, :free_form, default: "JSON", values: ["JSON", "XML", "TEXT"]


	it "can make a restful GET that returns valid JSON" do 
		action = Rules::Action.new({ type: Rules::Handlers::WebService,  
																		context_mapping: { "service_url:=>string" => 'https://api.imgur.com/3/gallery/hot/viral/day/0.json:=>free_form',
																											"service_method:=>select" => 'GET:=>free_form',
																											"content_type:=>select" => ':=>free_form',
																											"response_type:=>select" => 'JSON:=>free_form',
																											"Authorization:=>string" => 'Client-ID caf76459de7eda6:=>free_form' },
																		template: { "params" => "", 
																								"headers" => "{Authorization}" }
																	})
		h = Rules::Handlers::WebService.new(action, {})
		result = h.handle
		expect(result.class).to eq Hash
	end
end