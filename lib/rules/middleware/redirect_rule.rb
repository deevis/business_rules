module Rules
  module Middleware
    class RedirectRule
      def initialize(app)
        @app = app
      end
         
      def call(env)
        #Thread.current[:redirect_url] = nil
        status, header, response = @app.call(env)
        #content_type = header["Content-Type"].split(";").first rescue "text/html"
        # if Thread.current[:redirect_url] && content_type == "text/html"   # Certainly not for text/javascript
        #   [ 301, 
        #     {"Location" => "#{Thread.current[:redirect_url]}"}, 
        #     ["Redirecting to permanent url"]]
        # else
        #   [status, header, response]
        # end
      end
    end
  end
end

