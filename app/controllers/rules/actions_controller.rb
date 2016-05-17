class Rules::ActionsController < ApplicationController
  
  def create
    @rule = Rules::Rule.find(params[:rule_id])
    @action = @rule.actions.create!(params[:rules_action])

    redirect_to (params[:event_id].presence ? rules_event_rule_url(@rule, event_id: params[:event_id]) : rules_rule_url(@rule)), :notice => "Action created!"
  end

  def destroy
    @rule = Rules::Rule.find(params[:rule_id])
    @rule.actions.delete(@rule.actions.find(params[:id]))

    redirect_to (params[:event_id].presence ? rules_event_rule_url(@rule, event_id: params[:event_id]) : rules_rule_url(@rule)), :notice => "Action deleted!"
  end

  def index
    @actions_config = Rules::Handlers::Base.actions_config 
    @actions = @actions_config.map{|type,needs| a= Rules::Action.new;a.type=type;a}
  end
  
end
