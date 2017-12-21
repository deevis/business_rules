module Rules
  module Handlers
    class Email < Rules::Handlers::Base

      needs :sender,      :messaging_user
      needs :recipient,   :messaging_user
      template :subject
      template :body

      def _handle
        rules_sender = sender 
        _from = (rules_sender == :system_messaging_user) ? Rules.system_messaging_user : rules_sender
        _to = recipient
        _subject = eval_template :subject
        _body = eval_template :body
        email = RulesMailer.send_rules_action_email        to: _to, 
                                                         from: _from, 
                                                      subject: _subject, 
                                                         body: _body 
        email.deliver_now
      end
    end
  end
end
