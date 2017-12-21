class Rules::Action < ActiveRecord::Base
  include Rules::ModelEventEmitter


  # field :title, type: String  
  # field :type, type: String								          # class name of handler
  # field :context_mapping, type: Hash, default: {}		# Map of actionNeed => ruleContextField {"actor:=>user"=>"actor:=>user"}
  
  # field :template, type: Hash, default: {} 			    # Map of templateName => templateValue { "email" => "hello {name}" }			
  
  # field :active, type: Boolean, default: true

  # field :future_configuration, type: Hash, default: nil

  # field :defer_processing, type: Boolean, default: false
  
  # embedded_in :rule, inverse_of: :actions
  belongs_to :rule 

  serialize :context_mapping, Hash
  serialize :template, Hash 
  serialize :future_configuration, Hash 


  before_save :set_default_mappings, :context_mapping_sanity_check
  
  def export
    {
      title: title,
      action_type: action_type,
      context_mapping: context_mapping,
      template: template, 
      future_configuration: future_configuration, 
      defer_processing: defer_processing
    }
  end

  # def template_export
  #   handler_class.templates.each_with_object({}) do |template_name, h|
  #     Rails.logger.info("Exporting template: #{template_name}")
  #     key = cms_template_key(template_name)
  #     Rails.logger.info("Exporting template cms values with key: #{key}")
  #     # content = Cms::Content.where(key: key).first
  #     # if content.present?
  #     #   h[template_name] = {}
  #     #   #h[template_name][:default] = template[template_name] if template[template_name].present?
  #     #   values = content.language_contents.each_with_object({}) do |lc,cms| 
  #     #     ml = Cms::MarketLanguage.find(lc["id"]) 
  #     #     if ml.present?
  #     #       lkey = "#{ml.market.name}::#{ml.language.name}(#{ml.language.language_code})"
  #     #       cms[lkey] = lc["v"] if lc["v"].present?
  #     #     else
  #     #       Rails.logger.warn("Unable to find MarketLanguage[#{lc['id']}]")
  #     #     end
  #     #   end
  #     #   h[template_name].merge! values
  #     # end
  #   end
  # end

  def future_configuration?
    !future_configuration.blank?
  end

  # an alias for future_configuration?
  def scheduled?
    future_configuration?
  end

  def continuation_strategy
    handler_class.continuation_strategy    
  end

  def testable?
    handler_class.testable?
  end

  # If this action has to be run in a synchronous fashion (ex: WebAlert, WebRedirect)
  # 
  # This is a class-level aspect and should be set within the subclasses Rules::Handlers::Base:
  #
  #     set_synchronous true
  #
  def synchronous?
    handler_class.synchronous?
  end

  def can_be_scheduled?
    !synchronous?
  end
  
  def can_defer_processing?
    !!(continuation_strategy)
  end

  def display_name
    "#{self.action_type.split("::").last.titleize}#{handler_class.display_name_details(self)}"
  end

  # An action is ready if all of it's needs are mapped
  def ready?
    return true unless strict_mapping?
    needs.each do |field, configuration|
      next if configuration[:optional] == true
      return false unless lookup_context_mapping(field,configuration[:type])
    end
    true
  end

  # returns true if this action should enforce all mappings exist in order to be ready
  def strict_mapping?
    action_type != "Rules::Handlers::CreateModel"
  end


  def needs
    needs_mappings = (handler_class.configuration[:needs].dup rescue {}) || {}
    class_lookup_cols = {}
    needs_mappings.each do |field,field_configuration|
      if field_configuration[:action_type] == :class_lookup
        klazz = self.lookup_context_mapping(field,:class_lookup)[0] rescue nil
        if klazz
          cols_to_add = Rules::Rule.get_columns(klazz.camelcase.constantize)
          cols_to_add.delete("id")
          cols_to_add.each do |column, type|
            class_lookup_cols[column] = {type: type}
          end
        end
      end
    end
    class_lookup_cols.each do |column, col_type|
      needs_mappings[column.to_sym] = col_type
    end
    template_names.each do |name|
      template_fields(name).each do |f|
        needs_mappings[f.to_sym] = {type: :string}
      end
    end
    needs_mappings
  end

  DONT_VALIDATE_AGAINST_RULE_CONTEXT = [:class_lookup, :free_form]

  # Basically remove any mapped fields that are not in the needs of this Action.
  # This can happen, for example, if a template's merge field is removed from the template
  def context_mapping_sanity_check
    allow_these = needs # These are action_fields
    delete_these_mappings = []
    context_mapping.each do |action_field, rule_field|
      action_field_name = action_field.split(":=>").first.to_sym
      unless allow_these[action_field_name] 
        Rails.logger.debug "[#{action_field}] is no longer one of our needs - deleting it from action_context"
        delete_these_mappings << action_field 
      end
      # If rule_field is mapped, make sure it's valid
      if rule_field.present? 
        rule_field_path = rule_field.split(":=>").first
        rule_field_type = rule_field.split(":=>").last.to_sym
        case rule_field_type 
        when :instance_lookup
          if !self.instance_lookup(rule_field_path)
            Rails.logger.debug "#{rule_field_path} did not evaluate to an actual instance - deleting"
            delete_these_mappings << action_field 
          end
        when :lambda_lookup
          #TODO - validate lambda lookup is valid
        else
          if !DONT_VALIDATE_AGAINST_RULE_CONTEXT.index(rule_field_type) && !rule.validate_context_path(rule_field_path)
            Rails.logger.debug "[#{rule_field_path}] is no longer valid for this rule context - deleting from action_context"
            delete_these_mappings << action_field 
          end
        end
      end
    end
    if delete_these_mappings.size > 0
      delete_these_mappings.uniq!
      Rails.logger.debug "\nContext mapping sanity check is removing mappings for the following:"
      delete_these_mappings.each do |m| 
        context_mapping.delete m 
        Rails.logger.debug "     #{m}"
      end
    end
  end

  def handler_class
    action_type.constantize
  end

  # What templates are defined for this Action's ActionHandler?
  # This reads from template DSL inside of ActionHandler class
  # Templates have to be defined through the DSL!!!
  def template_configuration
    (handler_class.configuration[:templates] rescue {}) || {}
  end


  def template_names
    template_configuration.keys rescue []
  end

  def template_body(template_name)
    body = template[template_name.to_s]                      # First try to read from Mongo Document template Hash
    body ||= template_configuration[template_name.to_sym]    # Not found, use the default configuration from the ActionHandler DSL
    body
  end

  # Extract the template fields for the provided template
  #
  # eg: body = "Hello {name}"    -  the mappable template field is :name
  # 
  # However, if the template field has a "." in it, then it is considered an interpolated and will
  #           only be included in the results if {include_interpolated: true} is passed
  #
  # eg: body = "Hello {recipient.display_name}"   -  there is no mappable template field, but rather
  #                                                  an expression that will be interpolated  
  #
  def template_fields(template_name, include_interpolated: false)
    template_fields_from_body(template_body(template_name), include_interpolated: include_interpolated)
  end

  def template_fields_from_body(template_body, include_interpolated: false)
    fields = (template_body.scan(/\{([^\s]*)\}/).flatten rescue []).uniq
    include_interpolated ? fields : fields.select{|f| !f.index(".")}

  end

  #TO-DO verify whether this method is used outside specs.
  #In import process sets "template" attribute first and  calls  "set_cms_defaults" that uses "template" attribute, to create CMS keys.
  #In rule-creation/updation process
  def set_template(template_name, template_body)
    # first make sure our fields are all ok in the new template_value
    fields = template_fields_from_body(template_body)
    fields.each do |f|
      template_body = template_body.gsub(f, f.downcase)
    end
    self.template[template_name] = template_body
  end


  # returns an array [field,type]
  def lookup_context_mapping(field, type = "string")
    context_mapping["#{field}:=>#{type}"].split(":=>") rescue nil  	
  end

  # Looks up an instance mapped as : "<class_name_underscored>[<id]"
  def instance_lookup(rule_field_name)
    matches = rule_field_name.match(/(.*)\[(.*)\]/)
    underscored_classname = matches[1]
    id = matches[2]
    underscored_classname.camelcase.constantize.find(id)
  end


  def set_default_mappings(rule_context = rule.try(:context) )
    needs.each do |action_field, configuration|
      Rails.logger.info "...Considering mapping for #{action_field}(#{configuration[:type]})"
      if configuration[:default]
        Rails.logger.info "......added [#{configuration[:default]}:=>free_form]"
        context_mapping["#{action_field}:=>#{configuration[:type]}"] ||= "#{configuration[:default]}:=>free_form"
      else
        if rule_context
          rule_context.keys.each do |rule_field|
            unless try_rule_mapping(rule_context,rule_field,rule_field,action_field,configuration[:type])
              try_rule_mapping(rule_context,rule_field,rule_field.split(".").last.to_sym,action_field,configuration[:type])
            end
          end
        end
      end
    end
  end    

  # A mapping equivalency is used to indicate two types can be mapped to each other, even though
  #   they do not have the same exact name
  def self.add_mapping_type_equivalency(target_type, equivalent_types)
    Rules.context_mapping_equivalencies[target_type] = equivalent_types
  end

  # action_type is the field being mapped into to (on the action)
  # rule_type is the field coming into the mapping from the rule
  def self.check_mapping_type?(action_type, rule_type)
    return true if action_type.downcase == rule_type.downcase || (action_type == "string" || action_type == "object")
    check_this = action_type.downcase.to_sym
    equivalencies = Rules.context_mapping_equivalencies[action_type.to_sym]   # action_type will be messaging_user, for example...
    if equivalencies && equivalencies.index(rule_type.downcase.to_sym)             # rule_type
      return true
    end
    false
  end

  def process_action(event, rule_context, action_chain_results = [])
    action_start = Time.now
    action_handler = self.action_type
    Rails.logger.info "\nRunning action: #{action_handler}"
    result = 0
    if !rule_context.running_future_action && self.future_configuration?
      Rails.logger.info "   This is to be run in the Future..."
      config = {
          event: event,
          rule_id: self.rule.id.to_s,
          action_id: self.id.to_s,
          action_handler: action_handler, 
          context_mapping: self.context_mapping.to_json,
          template: self.template.to_json
        }.merge(self.future_configuration)  # future_configuration values will come in as strings, not symbols
      # Need to have actor and trigger in scope 
      #actor = User.find( event["user"]["id"]) rescue nil
      #trigger = event["klazz"].constantize.find(event["id"]) rescue nil
      config[:run_at] = eval(config["run_at_expression"], rule_context.get_binding) rescue Time.now
      config[:unique_id] = eval(config["unique_expression"], rule_context.get_binding) rescue nil
      Rails.logger.info "   configuring FutureAction with: #{config}\n"
      Rails.logger.debug " First check if the uniq id already exists, and if so reconfigure it"
      unique_action = Rules::FutureAction.where(unique_id: config[:unique_id]).first unless config[:unique_id].blank?
      if unique_action
        Rails.logger.debug " We found an existing FutureAction based on unique_id - updating"
        unique_action.update( config )
        Rails.logger.debug " updated FutureAction[#{unique_action.id}] found with uniq_id[#{config[:unique_id]}]"
      else
        Rails.logger.debug " creating FutureAction"
        fa = Rules::FutureAction.create( config )
        Rails.logger.debug " created FutureAction[#{fa.id}]"
      end
    else
      Rails.logger.info("Running as FutureAction") if rule_context.running_future_action
      klass = action_handler if action_handler.is_a? Class
      #Module.const_get(action_handler) doesn't work for nested classes
      #We can use String.constantize (ActiveSupport extension for string)
      #or eval works for sure.
      klass = action_handler.constantize rescue nil if action_handler.is_a? String  
      # Run the ActionHandler!!!
      result = Rules.rule_context_around.call(event) do
        klass.new(self, event, rule_context, action_chain_results).handle if klass
      end
      action_chain_results << result
      if self.defer_processing?
        return :defer_processing  
      end
    end
    Rails.logger.info " Finished action: #{action_handler}\n"
    return result
  rescue => e 
    Rails.logger.error "ERROR: Running action #{self.action_type} for rule #{rule.name}: #{e.message}\n"
    Rails.logger.error e.backtrace.join("\n")
    return :error
  ensure 
    action_stop = Time.now
    if (( action_stop - action_start) > 0.5)
      Rails.logger.warn "PERFORMANCE: Rule[#{self.rule.name}] Action[#{action_handler}] took a while [#{action_stop - action_start} seconds] to evaluate criteria"
    end
    Rules::RulesActionAnalytics.track(self, rule_context)
  end

  private
    def try_rule_mapping(rule_context,rule_field,rule_field_check,action_field,type)
      if rule_field_check == action_field
        rule_type = rule_context[rule_field]
        if rule_type && ((rule_type.to_sym == type.to_sym) || action_field == :trigger )
          # The name and type matched - make the default entry
          Rails.logger.debug "...Adding default mapping for #{action_field}:=>#{type} ==> #{rule_field}:=>#{rule_type}"
          context_mapping["#{action_field}:=>#{type}"] = "#{rule_field}:=>#{rule_type}"
          return true
        end
        return false
      end
    end


end
