class Rules::EventsController < ApplicationController
  def index
    @events_tree = Rules::RulesConfig.events_tree
    respond_to do |format|
      format.html
    end
  end

  def show
    @event = Rules::RulesConfig.event params[:id]
    @rules_rules = Rules::Rule.where(event: @event[:name]).all
    respond_to do |format|
      format.html
      format.json { render json: @event, include: [:comments] }
    end
  end
  
end
