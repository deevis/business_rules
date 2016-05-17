require 'net/ftp'

module Rules
	module Handlers
		class FtpUploader < Rules::Handlers::Base

			needs :server_url, :string
			needs :username, :string				# epicure
			needs :password, :string				# N38gen2tNFs12pn

			needs :remote_directory, :string, default: "."
			needs :filepaths, :string

			def _handle 
        files_uploaded = []
        puts "FtpUploader connecting to [#{server_url}]"
        ftp = Net::FTP.new(server_url)
        ftp.passive = true
        ftp.login username, password
      	ftp.chdir(remote_directory)
      	files_to_upload = (filepaths.class == Array) ? filepaths : [filepaths]
      	files_to_upload.each do |filename|
      		if File.file?(filename)
        		puts "  uploading [#{filename}]"
        		ftp.putbinaryfile( filename )
        		files_uploaded << filename 
        	else
        		puts "  skipping missing file [#{filename}]"
        	end
      	end
        puts "All files uploaded"
        files_uploaded
      rescue => e 
      	puts e.message
      	puts e.backtrace
      	false
      ensure
      	ftp.close rescue nil
			end

		end
	end
end
