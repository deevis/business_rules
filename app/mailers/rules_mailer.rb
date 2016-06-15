class RulesMailer < ApplicationMailer
  layout 'rules_mailer'
  
  def send_rules_action_email(to:, subject:, body: , from: )
    @body = body
    to = _get_email to
    from = (String === from) ? from : from.email 
    mail( to: to,
        subject: subject,
        from: from)
  end


  def _get_email x 
    return x if String === x
    [:email, :email_address, :email1].each do |m| 
      return x.send(m) if x.respond_to?(m)
    end
    raise "Unable to determine email address for #{x} when sending from RulesMailer"
  end

end
