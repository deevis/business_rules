require 'spec_helper'

			# needs :server_url, :string
			# needs :username, :string				# 
			# needs :password, :string				# 

			# needs :remote_directory, :string, default: "."
			# needs :file_paths, :string

describe 'Rules::Handlers::FtpUploader' do 
	it 'can upload test.txt from ftp3.buzztrends.net as epicure user' do 
		filepath = File.join('spec','support', 'rspec.txt')
		# Epicure User isn't around anymore?!?
		# action = Rules::Action.new({ type: Rules::Handlers::FtpUploader,  
		# 																context_mapping: { "server_url:=>string" => 'ftp3.buzztrends.net:=>free_form',
		# 																									"username:=>string" => 'username:=>free_form',
		# 																									"password:=>string" => 'password:=>free_form',
		# 																									"remote_directory:=>string" => '.:=>free_form',
		# 																									"filepaths:=>string" => "#{filepath}:=>free_form" }
		# 																								})
		# h = Rules::Handlers::FtpUploader.new(action, {}, nil)
		# result = h.handle
		# expect(result.index(filepath)).to_not be nil
	end
end