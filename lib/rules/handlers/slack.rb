module Rules
  module Handlers
    class Slack < Rules::Handlers::Base

      # integration_ids is something like:
      #   T025DQN36/B01370Y43K6/GQ73kprALSMIiXUguEPoYhZi
      needs :integration_ids, :string
      template :message

      def _handle
        headers = { "Content-type" => "application/json" }
        json_body = {text: eval_template(:message) }
        url = "https://hooks.slack.com/services/#{integration_ids}"
        r = HTTParty.send :post, url, {body: json_body.to_json, headers: headers}
      end
    end
  end
end
