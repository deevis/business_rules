module Rules
	module Handlers
		class FileWriter < Rules::Handlers::Base

			needs :filepath, :string
			needs :code_or_template, :select, default: "code", values: ["code", "template"]
			needs :append, :boolean, default: false 

			template :body

			def _handle 
				mode = append ? "wb" : "w"
				contents = (code_or_template == "code") ? eval(:body) : eval_template(:body)
				File.open( filepath, mode) do |f|
					f.write( contents )
				end
				return filepath
			end

		end
	end
end