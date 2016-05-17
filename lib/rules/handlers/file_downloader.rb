module Rules
	module Handlers
		class FileDownloader < Rules::Handlers::Base

			needs :url, :string
			needs :storage_directory, :string

			def _handle 
				download_these = (url.class == Array) ? url : [url]
				result = []
				download_these.each do |download_url|
	        file_uri = URI.parse(download_url)
	        puts "   DEBUG: Downloading [#{download_url}]"
	        filename = File.basename(file_uri.path)
	        filepath = "#{storage_directory}/#{filename}".gsub("//","/")
	        open(filepath, 'wb') do |file|
	          file << open(file_uri).read
	        end
        	result << filepath
	      end
	      puts "Returning #{result}"
	      puts "Returning #{result}"
	      return result
			end

		end
	end
end
