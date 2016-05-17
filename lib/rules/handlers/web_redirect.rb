module Rules
  module Handlers
    class WebRedirect < Rules::Handlers::Base

      set_synchronous true
      set_testable true
            
      # This is the URL that will be redirected to
      needs :url, :string

      # This regular expression will halt redirection if the url being redirected from matches
      needs :url_exceptions_regexp, :string, optional: true

      def _handle
        uer = url_exceptions_regexp
        from_url = event[:original_url] rescue ""
        Rails.logger.info "WebRedirect._handle: Got from_url: #{from_url} "
        rule_id = action.rule.id.to_s rescue ""
        if Rules::Handlers::WebRedirect.should_redirect?( from_url , uer)
          redirect_url = url
          if redirect_url.index("?")
            redirect_url = "#{redirect_url}&redirect_rule_id=#{rule_id}"
          else
            redirect_url = "#{redirect_url}?redirect_rule_id=#{rule_id}"
          end
          config = {redirect_url: redirect_url,
                    redirect_url_exceptions_regexp: uer }
          Rails.logger.info "WebRedirect._handle: Redirecting to [#{redirect_url}]"
          Rules::WebActionsQueue.add(self, config )
          return redirect_url
        else
          Rails.logger.warn "WebRedirect._handle: Not redirecting from [#{from_url}] due to uer[#{uer}] - :abort_action_chain"
          return :abort_action_chain
        end
      end

      # Use the url_exceptions_regexp to determine whether a redirection from a specified url is allowed
      def self.should_redirect?(from_url, url_exceptions_regexp)
        return true if from_url.blank? 
        default_exceptions = Rules.disallow_web_redirects_from
        url_exceptions_regexp = [url_exceptions_regexp.presence,default_exceptions.presence].compact.join("|")
        return true if url_exceptions_regexp.blank?
        scrubbed = url_exceptions_regexp.gsub(",","|").gsub(" ","")
        r = Regexp.new scrubbed
        should_restrict_match = from_url.scan r
        Rails.logger.info "WebRedirect.should_redirect?('#{from_url}', '#{scrubbed}') : #{should_restrict_match}"
        should_restrict_match.size == 0
      end
      
    end
  end
end