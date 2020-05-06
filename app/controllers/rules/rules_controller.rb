module Rules
class RulesController < ApplicationController

  skip_before_action :verify_authenticity_token
  
  include ActionController::StrongParameters

  # before_filter :admin_required    # If you include Rules, you want this controller SECURE!!!

  def lookup_events
    r = Regexp.new(".*#{params[:q]}.*", "i")
    list = Rules::RulesConfig.events.grep r
    render json: list.first(10).map{|e| {id: e.gsub("::","__") ,value: e}}
  end

  def add_event
    @rules_rule = Rules::Rule.find(params[:id])
    event = params[:event].gsub("__","::") rescue nil
    event_list = event.split(",")
    events_added = []
    event_list.each do |e| 
      unless e.blank? || @rules_rule.events.index(e)
        @rules_rule.events << e 
        events_added << e 
      end
    end
    @rules_rule.updated_actions << "Added #{events_added.join(",")} as trigger(s)"
    if @rules_rule.save
      redirect_back fallback_location: rules_rules_path, notice: "#{events_added.join(",")} is a trigger for this rule"
    else
      redirect_back fallback_location: rules_rules_path, error: "Could not add event: #{event}.  Suggest you check the logs and maybe this will help, too: #{@rules_rule.errors}"
    end
  end

  def remove_event
    @rules_rule = Rules::Rule.find(params[:id])
    event = params[:event].gsub("__","::") rescue nil
    @rules_rule.events.delete event
    @rules_rule.updated_actions << "Removed #{event} as a trigger"
    if @rules_rule.save
      redirect_back fallback_location: rules_rules_path, notice: "#{event} is no longer a trigger for this rule"
    else
      redirect_back fallback_location: rules_rules_path, error: "Could not remove event: #{event}.  Suggest you check the logs and maybe this will help, too: #{@rules_rule.errors}"
    end
  end

  def dynamic_event_fields 
    @rules_rule = Rules::Rule.find(params[:id])
    render :dynamic_event_fields, layout: false
  end

  def post_dynamic_event_fields 
    @rules_rule = Rules::Rule.find(params[:id])
    klazz = params[:event_klazz].presence || "*"
    action = params[:event_action].presence 
    @rules_rule.events = @rules_rule.events.map{|e| (e =~ /DynamicEvent.*::.*/) ? "DynamicEvent<#{klazz}>::#{action}"  : e }
    @rules_rule.save!
    redirect_to @rules_rule
  end

  def lookup_actions
    r = Regexp.new(".*#{params[:q]}.*", "i")
    list = Rules::Handlers::Base.action_listing.map(&:to_s).grep r
    render json: list.first(10).map{|a| {id: a.gsub("::","__") ,value: a}}
  end

  def notifications
    h = Hash.new {|h,k| h[k] = [] }
    @notifications_by_category = Rules::Rule.joins(:actions).
      where('action_type like ?', '%Notification%').each do |r| 
      h[r.category] += r.actions.select {|a| a.action_type =~ /.*Notification/ }
    end
    h
  end
  def add_action
    @rules_rule = Rules::Rule.find(params[:id])
    action_type = params[:action_class].gsub("__","::") rescue nil
    if action_type
      @action = Rules::Action.new(action_type: action_type)
      @rules_rule.actions << @action
      msg = "Added Action: #{action_type}"
      @rules_rule.updated_actions << msg
    else       
      msg = "Please pass in action to add as :action_class parameter"
    end
    if action_type && @rules_rule.save
      @action_id = @action.id
      _smart_redirect(notice: msg)
    else
      redirect_back fallback_location: rules_rules_path, error: "Could not add event: #{action_type}.  Suggest you check the logs and maybe this will help, too: #{@rules_rule.errors}"
    end
  end

  def export
    @rules_rules = Rules::Rule.all
  end

  # Import will work for multiple rules each with standard yaml header of "---\n"
  def do_import
    rules_data = params[:import][:data]
    force = params[:import][:override_by_name] == "1"
    imported, noop, failed = 0, 0, 0
    rules_data = rules_data.gsub("\r\n", "\n")
    rules_data.split("---\n").each do |rule_config|
      next if rule_config.blank?
      data = YAML.load(rule_config)
      begin
        r = Rules::Rule.import(data, filepath: data[:definition_file], overwrite: force)
        if r.created_at > 5.seconds.ago 
          imported += 1 
        else
          noop += 1
        end
      rescue => e 
        Rails.logger.error(e.message)
        Rails.logger.error(e.backtrace.join("\n"))
        failed += 1
      end
    end
    msg = "Import processed <br/><br/>  Imported: #{imported} <br/>  Noop: #{noop} <br/>  Failed: #{failed}"
    Rails.logger.info msg
    redirect_back fallback_location: rules_rules_path, notice: msg
  end

  def show_yaml
    @rules_rule = Rules::Rule.find(params[:id])
    render :show_yaml, layout: false
  end

  # This is to turn on and off the streaming of events and rule activity to Rules.rule_activity_channel
  def toggle_activity_channel_enabled
    enabled = (params[:enabled] == 'true')
    Rules.set_rule_activity_channel_enabled(enabled) 
  end

  def toggle_active
    @rules_rule = Rules::Rule.find(params[:id])
    active = params[:active]
    @rules_rule.active = (active == "true")
    @rules_rule.updated_actions << "Set active = #{@rules_rule.active}"
    @rules_rule.save!
  end

  def fresh_start 
    raise "Offlimits in Production - find another way" unless Rails.env.development?
    Rules::RulesConfig.delete_rules
    Rules::RulesConfig.import_rules
    redirect_back fallback_location: rules_rules_path, notice: "Rules reloaded - you still have to manually Reload Configuration"
  end

  def remove_action
    @rules_rule = Rules::Rule.find(params[:id])
    action_id = params[:action_id] rescue nil
    action = @rules_rule.actions.detect{|a| a.id.to_s == action_id}
    action.delete if action
    msg = "Removed Action: #{action}"
    @rules_rule.updated_actions << msg
    if @rules_rule.save
      _smart_redirect(notice: "Action deleted")
    else
      redirect_back fallback_location: rules_rules_path, error: "Could not remove action.  Suggest you check the logs and maybe this will help, too: #{@rules_rule.errors}"
    end
  end

  def move_action_downwards
    _move_action(1)
  end

  def move_action_upwards 
    _move_action(-1)
  end

  def _move_action(offset)
    @rules_rule = Rules::Rule.find(params[:id])
    @action_id = params[:action_id] rescue nil
    actions = @rules_rule.actions
    action = actions.detect{|a| a.id.to_s == @action_id}
    pos = actions.index action 
    if pos && (pos + offset >= 0) && (pos + offset <= actions.size)
      @rules_rule.swap_action_order(pos, pos+offset)
    end
    _smart_redirect
  end    

  def toggle_future_action
    @rules_rule = Rules::Rule.find(params[:id])
    action_id = params[:action_id] rescue nil
    action = @rules_rule.actions.detect{|a| a.id.to_s == action_id}
    if action.future_configuration?
      operation = "Disabled Future Scheduling"
      action.future_configuration = nil
    else
      operation = "Enabled Future Scheduling"
      action.future_configuration = {   run_at_expression: 'Time.now + 1.day',
                                        unique_expression: '', 
                                        recurring_expression: '',
                                        contingent_script: 'trigger != nil',
                                        priority: 0 }
    end
    @rules_rule.updated_actions << operation
    if @rules_rule.save
      _smart_redirect(notice: operation)
    else
      redirect_back fallback_location: rules_rules_path, error: "Could not change Future Scheduling of Action.  Suggest you check the logs and maybe this will help, too: #{@rules_rule.errors}"
    end
  end


  def toggle_defer_processing
    @rules_rule = Rules::Rule.find(params[:id])
    action_id = params[:action_id] rescue nil
    action = @rules_rule.actions.detect{|a| a.id.to_s == action_id}
    if action.defer_processing?
      operation = "Removed deferred processing of action chain"
      action.defer_processing = false
    else
      operation = "Added deferred processing of action chain"
      action.defer_processing = true
    end
    @rules_rule.updated_actions << operation
    if @rules_rule.save
      _smart_redirect(notice: operation)
    else
      redirect_back fallback_location: rules_rules_path, error: "Could not toggle deferred processing of action chain.  Suggest you check the logs and maybe this will help, too: #{@rules_rule.errors}"
    end
  end



  def set_future_field
    @rules_rule = Rules::Rule.find(params[:id])
    action_id = params[:action_id] rescue nil
    action = @rules_rule.actions.detect{|a| a.id.to_s == action_id}
    if action.future_configuration[params[:field]] != params[:value]
      action.future_configuration[params[:field]] = params[:value]
      @operation = "Set future configuration #{params[:field]} to [#{params[:value]}]"
      @rules_rule.updated_actions << @operation
      @rules_rule.save!
    else
      @operation = "Field mapping already set"
    end
  end

  def lookup_sub_properties
    @rule = Rules::Rule.find(params[:rule_id])
    @div_id = request[:div_id]
    @path = params[:path]
    @ctx = @rule.lookup_path(@path)
    respond_to do |format|
      format.js {}
      format.json { render json: @ctx }
    end
  end

  #
  #  add_action_mapping:  (from rule_field to action_field)
  #  
  #  rule_field:  actor:user
  #        name: actor
  #        type: user
  #
  #  action_field: sender:messaging_user
  #        name: sender
  #        type: messaging_user
  #  
  #  Special cases:
  #   1) action_field_type == :class_lookup
  #   2) rule_field_type == :instance_lookup
  #   3) rule_field_type == :freeform    ( rule_field_name will be the value to use )
  #  
  #  DBH local test: http://lvh.me:3000/rules/rules/53600f3664617219ec0a0000/add_action_mapping?action_id=53601e3e64617257a0090000&rule_field=my_value:freeform&action_field=featureable_type:string
  #
  def add_action_mapping
    @rules_rule = Rules::Rule.find(params[:id])
    action_id = params[:action_id]
    rule_field = params[:rule_field]
    action_field = params[:action_field]
    @action = @rules_rule.actions.detect{|a| a.id.to_s == action_id}
    @was_mapped = @action.context_mapping[action_field]
    @action_field_name = action_field.split(":=>").first
    @action_field_type = action_field.split(":=>").last
    @rule_field_name = rule_field.split(":=>").first
    @rule_field_type = rule_field.split(":=>").last
    if @action_field_type == :class_lookup 
      klazz = @rule_field_type.constantize
      @action.context_mapping[action_field] = rule_field
      @action.save!
      @rules_rule.updated_actions << "Added class lookup : #{rule_field}"
      @rules_rule.save!
    elsif @rule_field_type == "instance_lookup"
      # In this case, the rule field name will be <className_underscored>[id]
      # The field type will be simple "instance_lookup" 
      # It will have some additional information which will be used for display purposes - perhaps - still fuzzy on that
      #
      # First - check that this is valid lookup
      instance = @action.instance_lookup(@rule_field_name)
      if instance 
        @action.context_mapping[action_field] = rule_field
        @action.save!
        @rules_rule.updated_actions << "Added class lookup : #{rule_field}"
        @rules_rule.save!
      else
        @error = "Unable to resolve instance specified by #{@rule_field_name}"
      end
    elsif @rule_field_type == "free_form" || @action_field_type == "free_form"
      begin
        config = @action.needs[@action_field_name.to_sym]
        check_value = @rule_field_name
        if config[:type] == :integer
          value = check_value.to_i
          raise "#{check_value} is not an integer" unless value.to_s == check_value
          if config[:min] && config[:min] > value 
            raise "You must enter a value that is #{config[:min]} or more"
          elsif config[:max] && config[:max] < value 
            raise "You must enter a value that is #{config[:max]} or smaller"
          end
        end
        @action.context_mapping[action_field] = rule_field
        @action.save!
        @rules_rule.updated_actions << "Added freeform action mapping : #{rule_field}"
        @rules_rule.save!
      rescue => e
        @error = "Unable to update mapping: #{e.message}"
      end
    elsif @rule_field_type == "lambda_lookup"
        @action.context_mapping[action_field] = rule_field
        @action.save!
        @rules_rule.updated_actions << "Added predefined action mapping : #{rule_field}"
        @rules_rule.save!      
    else
      if Rules::Action.check_mapping_type?(@action_field_type, @rule_field_type)
        @action.context_mapping[action_field] = rule_field
        @action.save!
        @rules_rule.updated_actions << "Added mapping : #{@rule_field_type} => #{action_field}"
        @rules_rule.save!
      else
        @error = "Illegal field type mapping from #{@rule_field_type} to #{@action_field_type}"
      end
    end
    respond_to do |format|
      format.html { _smart_redirect(error: @error) }
      format.js {}
    end
  end


  def remove_action_mapping
    @rules_rule = Rules::Rule.find(params[:id])
    @action_id = params[:action_id]
    action_field = params[:action_field]
    @action = @rules_rule.actions.detect{|a| a.id.to_s == @action_id}
    @action_field_name = action_field.split(":=>").first
    @action_field_type = action_field.split(":=>").last
    mapped_from = @action.context_mapping[action_field] 
    if mapped_from
      @action.context_mapping[action_field] = nil
      @action.save!
      @rule_field_name = mapped_from.split(":=>").first
      @rule_field_type = mapped_from.split(":=>").last
      @message = "Removed field mapping for #{@action_field_name}"
      @rules_rule.updated_actions << @message
      @rules_rule.save!
    else
      @message = "#{action_field} was not mapped"
    end

    respond_to do |format|
      format.html { _smart_redirect }
      format.js {} 
    end
  end

  def lookup_class
    filter = params[:filter] || ".*"
    strategy = Rules.instance_lookups[params[:lookup_type].to_sym]
    if strategy == :model_events
      model_classes = Rules::RulesConfig.events_config[:model_events].keys 
    elsif strategy.blank?
      model_classes = []
      # params[:klazz] = 'free_form'  # view will need this... we are short-circuiting the normal here
      # respond_to do |format|
      #   format.html { render "lookup_class_instance", layout: false}
      #   format.js { render "lookup_class_instance"}
      # end
      # return
    else
      model_classes = strategy.keys
      @lambdas_predefined = strategy[:lambda_lookup][:predefined] rescue nil
    end
    r = Regexp.new(filter)
    @classes = model_classes.select{|mc| mc.class == String && mc =~ r}.sort
    respond_to do |format|
      format.html { render layout: false}
      format.json { render json: @classes }
      format.js { render layout: false}
    end
  end

  def lookup_class_instance
    klazz = params[:klazz]
    if klazz != "free_form"
      lookup_type = params[:lookup_type].to_sym
      lookup = Rules.instance_lookups[lookup_type]
      meta_config = lookup[klazz] || {}
      @search_fields = meta_config[:search] || 
                              Rules::Rule.get_columns(klazz.camelcase.constantize)
                              .slice('name', 'name', 'first_name', 'last_name', 
                                'title', 'email', 'description', 'content', 'status').keys rescue []
      @display_template = meta_config[:display] || "attributes.slice('id', 'name', 'first_name', 'last_name', 'title', 'email', 'description', 'content', 'status')"
      @results = klazz.camelcase.constantize.all
      search_params = params[:search] || []
      search_params.each do |field, value|
        @results = @results.where("#{field} like '%#{value}%'") unless value.blank?
      end
      @results = @results.order("#{@search_fields.first} ASC") if @search_fields.length > 0
      @results = @results.page(params[:page]).per(20)
    end
    respond_to do |format|
      format.json { render json: {search_fields: @search_fields, display_template: @display_template, results: @results }}
      format.js {}
      format.html { render layout: false}
    end
  end

  def set_timer_event_class
    @rules_rule = Rules::Rule.find(params[:id])
    klazz = params[:klazz].try(:camelcase)
    @rules_rule.events = @rules_rule.events.map{|e| (e =~ /TimerEvent.*/) ? "TimerEvent<#{klazz}>::tick"  : e }
    @rules_rule.save!
    redirect_to @rules_rule
  end


  def dashboard

  end
  
  def clone 
    clone_this_one = Rules::Rule.find(params[:id])
    @title = "'#{clone_this_one.name}' cloned"
    @rules_rule = clone_this_one.clone 
    @rules_rule.name = "(Clone) #{@rules_rule.name}"
    @rules_rule.description = "(Clone) #{@rules_rule.description}"
    @rules_rule.updated_actions << "Cloned from #{clone_this_one.id.to_s}" 
    @rules_rule.was_valid = clone_this_one.ready?
    @rules_rule.active = false
    if @rules_rule.save
      render :edit
    else 
      redirect_to rules_rule_path(clone_this_one), 
          alert: @rules_rule.errors.full_messages.join("<br/>")
    end
  end

  def reload_rules_engine
    c = Rules::RulesEngine.reload_configuration
    notice = "Rules configuration is being reloaded across the cluster, far and wide."
    redirect_to rules_rules_path, notice: notice
  end

  # GET /rules/rules
  # GET /rules/rules.json
  def index
    fe = params[:event].presence 
    fa = params[:action_type].presence
    fc = params[:category].presence
    fq = params[:q].presence
    Rails.logger.info "Rules Filter event[#{fe}] action[#{fa}] category[#{fc}] q[#{fq}]"
    scope = params[:deleted] == 'true' ? Rules::Rule.unscoped : Rules::Rule
    scope = scope.where("json_contains(events, '#{fe.to_json}')") if fe
    scope = scope.joins(:actions).where(rules_actions: {action_type: fa}) if fa
    scope = scope.where(category: fc) if fc
    if fq 
      scope = scope.where("description like ?", "%#{fq}%")
                .or(Rules::Rule.where("name like ?", "%#{fq}%"))
                .or(Rules::Rule.where("criteria like ?", "%#{fq}%"))
      # scope = scope.any_of( {events: @q_regexp},
      #                       {description: @q_regexp}, 
      #                       {name: @q_regexp}, 
      #                       {criteria: @q_regexp},
      #                       {:actions.elem_match => {"template.body" => @q_regexp}})
    end
    scope = scope.order("updated_at DESC")
    @rules_rules = scope
    @rules_rules = @rules_rules

              #  .ne(_deleted: true) unless params[:deleted] == "true"

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @rules_rules }
    end
  end

  # GET /rules/rules/1
  # GET /rules/rules/1.json
  def show
    @rules_rule = Rules::Rule.find(params[:id])

    respond_to do |format|
      format.html { 
        if params[:old].blank?
          render "show2"
        else
          render "show"
        end
       } # show.html.erb
      format.json { render json: @rules_rule }
    end
  end

  def test_rule
    @rules_rule = Rules::Rule.find(params[:id])
    action_id = params[:action_id].presence

    # OK - this will be interesting...
    tested_actions = []
    @rules_rule.actions.each_with_index do |action,idx| 
      next if action_id.present? && action.id.to_s != action_id
      if action.testable?
        a = action.clone
        test_context = a.handler_class.test_context(a)
        a.process_action({}, test_context)
        tested_actions << "Action #{idx+1} : #{a.type}"
      end
    end
    msg = tested_actions.blank? ? "No Actions were tested" : "Tested: <br>#{tested_actions.join('<br>')}"
    redirect_to rules_rule_path(@rules_rule, action_id: action_id), notice: msg
  end

  def show_action_configuration
    @rules_rule = Rules::Rule.find(params[:id])
    @action = @rules_rule.actions.detect{|a| a.id.to_s == params[:action_id]}
  end

  # GET /rules/rules/new
  # GET /rules/rules/new.json
  def new
    @rules_rule = Rules::Rule.new
    @rules_rule.event = params[:event] if params[:event]

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @rules_rule }
    end
  end

  # GET /rules/rules/1/edit
  def edit
    @rules_rule = Rules::Rule.find(params[:id])
  end


  # POST /rules/rules
  # POST /rules/rules.json
  def create
    sp = params.require(:rules_rule).permit(:name, :description, :category)
    @rules_rule = Rules::Rule.new(sp)

    respond_to do |format|
      @rules_rule.updated_actions = ["Rule created"]
      if @rules_rule.save
        format.html { _smart_redirect(notice: 'Rule was successfully created.') }
        format.json { render json: @rules_rule, status: :created, location: @rules_rule }
      else
        format.html { render action: "new" }
        format.json { render json: @rules_rule.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /rules/rules/1
  # PUT /rules/rules/1.json
  def update
    @rules_rule = Rules::Rule.find(params[:id])
    # {"action"=>{"522e0313a4c6b2154c000001"=>{"template"=>{"name"=>"asdf"}}}}
    action_update = params[:rules_rule].delete(:action) rescue nil
    if action_update 
      @action_id = action_update.keys.first
      action = @rules_rule.actions.detect{|a| a.id.to_s == @action_id}
      puts "Updating Rule #{@rules_rule.name}- Action #{action.class}"
      template_name = action_update.values.first[:template].keys.first
      template_value = action_update.values.first[:template].values.first
      puts "TemplateName[#{template_name}]  TemplateValue[#{template_value}]"
      action.set_template(template_name, template_value)
      @rules_rule.updated_actions << "Updated template : #{template_name}"
      @rules_rule.save!
    end

    record_history_changes(:unique_expression)
    record_history_changes(:criteria)
    respond_to do |format|
      if @rules_rule.update_attributes(params[:rules_rule].permit!)
        format.html { _smart_redirect(notice: 'Rule was successfully updated.') }
        format.json { head :no_content }
      else
        format.html { render :show2 }
        format.json { render json: @rules_rule.errors, status: :unprocessable_entity }
      end
    end
  end

  def record_history_changes(property)
    b4 = @rules_rule.send(property).presence
    after = params[:rules_rule][property].presence
    if b4 != after
      _index = @rules_rule.updated_actions.length - 1
      @rules_rule.updated_actions[_index] += "\nChanged unique expression from [#{b4}] to [#{after}]."
    end      

  end

  def _smart_redirect(options = {}) 
    notice = options[:notice] # || @rules_rule.updated_action
    error = options[:error] 
    error ||= options[:errors].full_messages.join("<br/>") if options[:errors].present?
    @action_id ||= params[:action_id]
    url = if params[:event].presence 
      rules_event_rule_url(@rules_rule, event: params[:event])
    else
      rules_rule_url(@rules_rule, action_id: @action_id)
    end
    redirect_to url, notice: notice, alert: error
  end    


  def validate_criteria
    @rules_rule = Rules::Rule.find(params[:id])
    @criteria = params[:criteria]  
    @eval_result, @errors = @rules_rule.validate_criteria(@criteria, true)
  end

  # The opposite of destroy, in this case...
  def undelete
    @rules_rule = Rules::Rule.find(params[:id])
    @rules_rule._deleted = false
    @rules_rule.active = false
    @rules_rule.updated_actions << "Undeleted"
    @rules_rule.save!
    redirect_to rules_rule_path(@rules_rule)
  end

  # DELETE /rules/rules/1
  # DELETE /rules/rules/1.json
  def destroy
    @rules_rule = Rules::Rule.find(params[:id])
    @rules_rule.destroy

    respond_to do |format|
      format.html { redirect_to (params[:event].presence ? rules_event_rules_url(event: params[:event]) : rules_rules_url) }
      format.json { head :no_content }
    end
  end

end
end
