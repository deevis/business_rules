class Rules::EventsController < ApplicationController

  skip_before_filter :admin_required, :only => [:push_event]
  skip_before_filter :login_required, :only => [:push_event]
  skip_before_filter :check_page_access, :only => [:push_event]

  def index
    @events_tree = Rules::RulesConfig.events_tree
    respond_to do |format|
      format.html
    end
  end

  def show
    @event = Rules::RulesConfig.event_config params[:id]
    @rules_rules = Rules::Rule.where(event: @event[:name]).all
    respond_to do |format|
      format.html
      format.json { render json: @event, include: [:comments] }
    end
  end

  #
  # Allow an external system to push events in via webservice calls
  #
  # The event must be passed in as a parameter
  #
  # eg:
  # 
  #   curl -X POST -H "Content-Type: application/json" -d '{ "event": "PyrTree::User::update", 
  #      "data":{"id":1,"client_user_id":"region_manager","first_name":"Fred","last_name":"Thomas"}, 
  #      "changes":{"first_name": ["Fredward", "Fred"]}}' http://localhost:3000/rules/events/push_event.json
  #
  #   {"success":true, "event":"PyrTree::User::update", "type":"ModelEvent",
  #      "klazz":"PyrTree::User", "action":"update"}
  #
  def push_event
    event = params[:event] 
    raise "Missing required parameter 'event'" unless event.present?
    event_config = Rules::RulesConfig.event_config(event)
    _, klazz, action = event.match( /(.*)::(.*)/ ).to_a
    if event_config.present?
      event_type = event_config[:type]
    else
      event_type = "DynamicEvent"
    end

    event_hash = {type: event_type, 
                    id: params[:trigger_id],     # Leave out id to work directly with values in :data
                 klazz: klazz,   # This is required for all ModelEvents
                  data: params[:data],            # required if :instance_id isn't present
                action: action,    # [create, update, delete]  (note: can't pass :action cuz rails!)
               changes: params[:changes] }        # { field_name: [before, after] }
    
    if params[:user_id].present?
      event_hash[:user] = {id: params[:user_id]}  # The ID of the Actor (in rule-speak)            
    end
    Rules::RulesEngine.raise_event(event_hash)

    render json: {  success: true, 
                      event: event, 
                       type: event_hash[:type], 
                      klazz: event_hash[:klazz], 
                     action: event_hash[:action] }
  rescue => e 
    Rails.logger.error "Error pushing event: #{params}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, event: event, message: e.message}
  end
  
end
