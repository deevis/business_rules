require 'rules/handlers/base'

class Rules::TestMessagingRecipientHandler < Rules::Handlers::Base
  include Rules::Handlers::MessagingRecipientEmitter 

  needs :recipient, :user
  template :message 
  
  def for_recipient(r)
    message = eval_template(:message)
    Thread.current[:test_email] = r.email
    Thread.current[:test_message] = message
  end

end