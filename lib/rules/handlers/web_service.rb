require 'httparty'

module Rules
	module Handlers
		class WebService < Rules::Handlers::Base

			needs :service_url, :string
			needs :service_method, :select, default: "GET", values: ["GET", "POST"] 
			needs :content_type, :select, default: "", values: ["", "text/xml", "application/json"]
			
			template :params  # merge fields created in here are used as the params for the call
			template :headers # merge fields created in here are used as headers

			needs :response_type, :select, default: "JSON", values: ["JSON", "XML", "TEXT"]

			def _handle
				# our params are every need that is not either :service_url or :method
				param_fields = @action.template_fields(:params, include_interpolated: false)
				header_fields = @action.template_fields(:headers, include_interpolated: false)
				q = {}.tap{|x| param_fields.each {|f| x[f] = self.send f.to_sym}}
				h = {}.tap{|x| header_fields.each {|f| x[f] = self.send f.to_sym}}
				h["Content-Type"] ||= content_type unless content_type.blank? 
				m = service_method.downcase.to_sym
				puts "CallWebService[#{m}] : [#{service_url}]"
				puts "  Query: #{q}"
				puts "  Headers: #{h}"
				args = { 	:headers => h }
  			if content_type.blank?
  				args[:query] = q 
  			else
  				args[:body] = eval_template(:params)
  			end
				r = HTTParty.send m, service_url, args
  				
  			result = process_result r
  			puts "\n\n Response: #{result}"
  			return result
			rescue => e 
				puts e.message
				puts e.backtrace
			end

			def process_result(response)
  			begin
  				if response_type == "JSON"
						response.as_json
	  			elsif response_type == "XML"
	  				raise "Can't handle the XML"
	  			else
	  				response.body
	  			end
	  		rescue => e 
	  			puts "  ERROR converting response to [#{response_type}]\n"
	  			puts " ### #{e.message} ###"
	  			puts response
	  			puts "\n"
	  			nil
	  		end
			end
		end
	end
end