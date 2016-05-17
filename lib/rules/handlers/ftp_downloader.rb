require 'net/ftp'

module Rules
	module Handlers
		class FtpDownloader < Rules::Handlers::Base

			needs :server_url, :string
			needs :username, :string				# epicure
			needs :password, :string				# N38gen2tNFs12pn

			needs :remote_directory, :string, default: "."
			needs :remote_file_selector, :string, default: ".*"
			
			needs :local_directory, :string

			def _handle 
        files_downloaded = []
        puts "FtpDownloader connecting to [#{server_url}]"
        ftp = Net::FTP.new(server_url)
        ftp.passive = true
        ftp.login username, password
				selector = Regexp.new(remote_file_selector)
        puts "Using remote file selector: [#{remote_file_selector}]"
        ldir = local_directory.end_with?("/" ) ? local_directory : "#{local_directory}/" 
        puts "Downloading to local folder [#{ldir}]"
      	ftp.chdir(remote_directory)
      	files_to_copy = ftp.nlst.select{|f| f =~ selector}
      	files_to_copy.each do |filename|
      		puts "  retrieving [#{filename}]"
      		ftp.getbinaryfile( filename, "#{ldir}/#{filename}" )
      		files_downloaded << filename 
      	end
        puts "All files downloaded"
        files_downloaded
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
