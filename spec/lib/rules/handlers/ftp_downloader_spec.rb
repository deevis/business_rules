require 'spec_helper'

			# needs :server_url, :string
			# needs :username, :string				# epicure
			# needs :password, :string				# N38gen2tNFs12pn

			# needs :remote_directory, :string, default: "."
			# needs :remote_file_selector, :string, default: ".*"
			
			# needs :local_directory, :string

describe 'Rules::Handlers::FtpDownloader' do 
	it 'can download test.txt from ftp3.icentris.com as epicure user' do 
		if File.file?("/tmp/test.txt")
			puts "Removing existing test.txt"
			File.delete("/tmp/test.txt")
		end
		# Epicure user isn't around anymore
		# action = Rules::Action.new({ type: Rules::Handlers::FtpDownloader,  
		# 																context_mapping: { "server_url:=>string" => 'ftp3.icentris.com:=>free_form',
		# 																									"username:=>string" => 'epicure:=>free_form',
		# 																									"password:=>string" => 'N38gen2tNFs12pn:=>free_form',
		# 																									"remote_directory:=>string" => '.:=>free_form',
		# 																									"remote_file_selector:=>string" => '.*\.txt:=>free_form',
		# 																									"local_directory:=>string" => '/tmp:=>free_form' }
		# 																								})
		# h = Rules::Handlers::FtpDownloader.new(action, {}, nil)
		# h.handle
		# expect(File.file?("/tmp/test.txt")).to be true
	end
end