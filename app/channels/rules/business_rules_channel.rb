class Rules::BusinessRulesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "business_rules"
  end 
end