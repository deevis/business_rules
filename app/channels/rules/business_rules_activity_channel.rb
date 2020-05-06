class Rules::BusinessRulesActivityChannel < ApplicationCable::Channel
  def subscribed
    stream_from "business_rules_activity"
  end 
end