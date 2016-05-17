module Rules
	module Handlers
		class FileProcessor < Rules::Handlers::Base

			needs :file_strategy, :string, values: ["Action Chain", "Location"]
			needs :filepath, :string
			needs :processing_strategy, :string, values: ["YML", "JSON", "Full Text", "Line processor"]

			template :processing_script

			def _handle 
        # file_strategy 
        file_url = URI.escape(url)
        open(filepath, 'wb') do |file|
          file << open(file_url).read
        end
        return filepath
			end

		end
	end
end
