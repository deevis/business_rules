require 'rules/action'
require 'resque'
require 'resque-scheduler'

module Rules
  class Rule 
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Rules::Versioning
    include Rules::ModelEventEmitter

    # If this is driven by a TimerEvent
    after_create :set_schedule
    after_save :set_schedule
    after_destroy :remove_schedule

    
    field :name, type: String 
    field :synchronous, type: Boolean, default: false # Should this run synchronously - must be true if any action handler is synchronous
    field :definition_file, type: String
    field :description, type: String
    field :events, type: Array, default: []
    field :category, type: String, default: "Uncategorized"
    field :criteria, type: String
    field :active, type: Boolean, default: true
    field :unique_expression, type: String  # will be evaluated against RuleContext and used with 
    # We will still have deleted in MongoDB as a dynamic field, but we're 
    # removing it from Mongoid as they will be using the method for their internals...
    #field :deleted, type: Boolean, default: false
    field :_deleted, type: Boolean, default: false

    field :start_date, type: Time
    field :end_date, type: Time

    # If this is driven by a TimerEvent, then specify the schedule
    field :timer, type: Hash, default: { next_fire: nil, last_fire: nil, expression: nil, recurring: false }
    field :timer_expression, type: String 

    # These can programatically be used to populate the events 
    field :event_inclusion_matcher, type: Regexp
    field :event_exclusion_matcher, type: Regexp

    # HACK - embedded documents are not Versionable 
    # http://stackoverflow.com/questions/4824677/mongoid-cant-make-versioning-work-with-embedded-document
    # So....saving the actions hash here so it will get versioned...
    field :actions_hashed, type: String

    embeds_many :actions, inverse_of: :rule

    before_save :set_synchronous, :context_mapping_sanity_check
    before_save :temp_migrate_deleted

    accepts_nested_attributes_for :actions

    validates :name, presence: true
    validates_uniqueness_of :name
    validate :validate_criteria_before_save

    def export
      {
        name: name,
        description: description,
        definition_file: definition_file,
        events: events,
        category: category, 
        unique_expression: unique_expression, 
        criteria: criteria,
        timer_expression: timer_expression,
        start_date: start_date, 
        end_date: end_date,
        actions: actions.map{|a| a.export} 
      }
    end

    def self.import(data, filepath: nil, overwrite: false)
      deprecated = data.delete(:deprecated)
      name = data[:name]
      description = data[:description]
      existing = Rules::Rule.where(definition_file: filepath).first if filepath
      existing ||= Rules::Rule.where(name: name).first
      if existing && deprecated
        Rails.logger.warn "Deleting Rule [#{name}]"
        existing.destroy
        return nil
      end
      if existing && !overwrite
        Rails.logger.info "\nDuplicate rule based on name [#{name}] and Description [#{description}]" 
        Rails.logger.info "Returning pre-existing Rule\n\n"
        return existing 
      end
      r = Rules::Rule.new(data)      
      Rails.logger.info("Saving rule [#{r.name}]")
      r.save!(validate: !(existing && overwrite))
      if existing && overwrite
        Rails.logger.warn "Overwriting existing rule"
        existing.destroy  # only destroy after the new rule has been successfully saved!!!
      end
      r
    end

    def ready?
      return false unless actions.present?
      !actions.collect{|a| a.ready?}.index false rescue false
    end

    def rule_deleted?
      return self["deleted"] || self._deleted
    end

    def testable?
      return false unless actions
      actions.each{|a| return true if a.testable?}
      return false
    end

    def testable_actions
      return [] unless actions
      actions.collect{|a| a.type if a.testable?}.uniq.compact
    end

    def run_timer?
      true
    end

    def get_timer_event
      events.detect{|e| e.start_with?("TimerEvent")}
    end

    def get_timer_event_class 
      get_timer_event.match(/.*<(.*)>.*/)[1] rescue nil
    end

    def get_dynamic_event
      events.detect{|e| e.start_with?("DynamicEvent")}
    end

    def get_dynamic_event_class 
      get_dynamic_event.match(/.*<(.*)>.*/)[1] rescue nil
    end

    def scheduled?
      get_timer_event
    end

    # Takes an event, determines whether to process the rule, and then processes it
    # 
    # Return codes:    0    Rule was fired
    #                 -1    Rule deleted - Did not fire 
    #                 -2    Rule inactive - Did not fire
    #                 -4    Criteria check failed - Did not fire
    #                 -3    Cycle-detected in event-action-chain - Did not fire
    # 
    def process_rule(event, deferred_action_chain = nil, extras = {})
      begin
        raise "Cannot process null event" if event.nil?
        return if Rules.disabled?
        start_time = Time.now
        current_rule_id = self.id.to_s
        puts "Considering processing rule #{current_rule_id}"
        if deferred_action_chain
          puts "\n\nRule.process_rule:: Resuming DeferredActionChain[#{deferred_action_chain.id}]..."
          action_chain_results = deferred_action_chain.action_chain_results
          # This Rule has technically already fired and may be in the processing stack - remove it now since we no we are re-running it
          event[:processing_stack].delete(current_rule_id)
        end
        action_chain_results ||= []
        #puts "--- event processing_stack: #{event[:processing_stack] || '---'}" 
        added_rule_ids = Rules::Rule.processing_stack_add(event[:processing_stack] || []) rescue []
        if self.rule_deleted?
          puts "NOT FIRING deleted rule"
          return -1
        end
        if !self.active
          puts "NOT FIRING inactive rule"
          return -2
        end
        if !deferred_action_chain && Rules::Rule.processing_stack.index(current_rule_id)
          puts "This Rule has already fired along this event-action-chain - not going to fire..."
          return -3
        end
        if !ready?
          puts "Rule is not ready"
          return -5
        end
        rule_context_id = "#{Time.now.to_i.to_s}-#{Digest::MD5.hexdigest(event.to_s)}"
        # publish to dashboard that rule is being evaluated
        Rules::Rule.publish_if_enabled({rule_context_guid: rule_context_id, status: "starting", 
                event: "#{event[:klazz]}::#{event[:action]}", processor_id: (extras[:processor_id] || :synchronous), 
                server_time: Time.now.strftime("%m/%d/%Y %H:%M:%S") }, self)
        rule_context = check_criteria(event, deferred_action_chain.present?, rule_context_id: rule_context_id) # Will return nil if the criteria evaluates to false, otherwise returns the action_context
        crit_time = Time.now
        if ((crit_time - start_time) > 0.25) 
          puts "PERFORMANCE: Rule[#{self.name}] took a while [#{crit_time - start_time} seconds] to evaluate criteria"
        end
        unless rule_context
          # publish to dashboard that rule did not pass
          Rules::Rule.publish_if_enabled({rule_context_guid: rule_context_id, status: "criteria_rejected", 
                event: "#{event[:klazz]}::#{event[:action]}" }, self)          
          puts "Criteria did not pass"
          return -4
        end
        should_not_be_empty = Rules::Rule.processing_stack_add([current_rule_id])  
        #puts "--- processing_stack b4 actions = #{Rules::Rule.processing_stack}" 

        raise "Unable to process rule as it was not added to the processing stack successfully" if should_not_be_empty.blank?

        added_rule_ids.push(*should_not_be_empty)
        self.increment_run_count unless deferred_action_chain
        while (rule_context.trigger) do
          if unique_firing_violated?(rule_context)
            rule_context.next_trigger
            next
          end
          actions.each_with_index do |action, i|
            if deferred_action_chain && action_chain_results.size > i 
              puts "... skipping action #{i} in action chain as resuming a DeferredActionChain that already has #{action_chain_results.size} actions performed"
              next
            end
            response_code = action.process_action(event, rule_context, action_chain_results)  # action_chain_results will have appended to it the 'work' performed by the action
            if response_code == :defer_processing 
              last_result = action_chain_results.last
              unless last_result.class.ancestors.index(ActiveRecord::Base)
                raise "Can't create deferred processing records unless result of deferring action is an ActiveRecord item"
              end
              # 1) Make sure DeferredActionChain record exists and/or update accordingly
              deferred_action_chain ||= Rules::DeferredActionChain.create( rule_id: self.id.to_s, event: event)
              # 2) Create new instance of ActionChainStep (referencing the result of this Action)
              deferred_action_chain.set_next_step(action.continuation_strategy, action_chain_results)  # 1-endian steps used so as to jive with UI 
              # 3) break loop to stop processing further actions
              break
            elsif response_code == :abort_action_chain
              puts "Aborting action chain as :abort_action_chain returned"
              break
            elsif response_code.present? 
              # nil is ok
              Rails.logger.warn "Unhandled response code: #{response_code}"
            end
          end
          mark_unique_fired(rule_context) if unique_expression.present?
          rule_context.next_trigger   # In the case that multiple_triggers were identified (mostly just for TimerEvents)
        end
        return 0  # Success, don't ya know...
      rescue => e
        puts "\n#{e.message}\n"
        puts e.backtrace
        # Update Dashboard with error status
        Rules::Rule.publish_if_enabled({ event: "#{event[:klazz]}::#{event[:action]}", 
                          rule_context_guid: rule_context_id, status: "error", error_message: e.message,
                          error_stacktrace: e.backtrace.to_s}, self)
        return -5
      ensure
        Rules::Rule.processing_stack_remove(added_rule_ids)  
        #puts "--- processing_stack after rule: #{Rules::Rule.processing_stack} "
        duration = Time.now - start_time
        if ((duration) > 0.5) 
          puts "PERFORMANCE: Rule[#{self.name}] took a while [#{duration} seconds] to fully process the Rule"
        end
        # Update Dashboard that processing of Rule has completed
        Rules::Rule.publish_if_enabled({rule_context_guid: rule_context_id, status: "finished", duration: duration}, self)
      end
    end

    
    #
    # Publish RulesEngine activity to Faye for display on Dashboard
    #
    def self.publish_if_enabled(payload, rule = nil)
      if Rules.rule_activity_channel_enabled && Rules.rule_activity_channel 
        begin
          if rule
            payload = payload.merge( {type: "rule", id: rule.id.to_s, name: rule.name, criteria: rule.criteria }) 
          end
          puts "\n\nPublishing to #{Rules.rule_activity_channel} : #{payload}\n\n"
          PrivatePub.publish_to Rules.rule_activity_channel, payload
        rescue => e 
          puts "Error publishing to #{Rules.rule_activity_channel} : #{e.message}"
          puts e.backtrace
        end
      end
    end


    # Determine overall Rule-scoped context via intersection of all event-scoped contexts
    def context 
      rc = {}
      return rc if events == nil || events.size == 0
      events.each_with_index do |e,i|
        if scheduled? 
          rc["system"] = :messaging_user 
          rc["trigger"] = get_timer_event_class
          break
        else
          ec = begin
            Rules::RulesConfig.event_config(e)[:context]
          rescue => e 
            Rails.logger.error("Unable to get Event configuration for event [#{e}] - returned empty hash {}")
            {}
          end
          if i == 0
            rc.merge!(ec)  # start with the first event's context
          else
            rc.each do |field, metadata|
              if ec[field] == nil
                # this event did not have the field in question, so it should not be in our interesected context
                rc.delete field     
              elsif ec[field] != rc[field]
                # if it is a trigger(x) type field, then don't delete it, but rather make it fall back to trigger(object)
                if field == "trigger"
                  rc[field] = :object
                else
                  rc.delete field     # this event had the field, but it was a different type, it cannot be in our intersected context
                end
              end # if ec[field] == nil
            end   # rc.each do |field, metadata|
          end     # if i == 0
        end       # if scheduled?
      end         # events.each_with_index do |e,i|

      HashWithIndifferentAccess.new(rc)
    end

    def context_field_mapped?(field,type)
      lookup = "#{field}:#{type}"
      actions.each do |a|
        return true if a.context_mapping.values.index lookup rescue false
      end
      false
    end


    def set_default_mappings
        puts "Setting default action mappings for [#{self.name}]"
        rule_context = context   #  {:actor=>:user, :trigger=>:object, etc...}
        actions.each do |a|
          a.set_default_mappings(rule_context)
        end
    end

    def swap_action_order(pos1, pos2)
      new_order = actions.dup
      actions.clear()
      new_order[pos1], new_order[pos2] = new_order[pos2],new_order[pos1]
      new_order.each{|a| self.actions.create a.attributes}
      reload
    end

    def increment_run_count
      
    end
    
    # Build and return a valid RuleContext based on the incoming event and any extras
    def self.rule_context(rule_event, extra_fields = {})
      Rules::RuleContext.new rule_event, extra_fields
    end

    # rule_event is a hash looking something like:
    # {
    #     type: "ControllerEvent|ModelEvent|TimerEvent",
    #     klazz: "ThingsController|User|TimerEvent",
    #     action: "index|create|tick"
    # }
    #
    # See RulesEngine.handle_event for more details on event hash
    #
    # check_criteria will return false if determined that the Rule should NOT fire
    #
    # check_criteria will return a valid RuleContext if determined that the rule should fire
    #
    def check_criteria(rule_event, skip_criteria_check = false, extras = {})
      Rules.rule_context_around.(rule_event) do
        unless skip_criteria_check
          rule_context = _check_criteria(rule_event, skip_criteria_check, extras)
          return false unless rule_context
        end
        puts "...building rule context..."
        # Check here for unique_rule_firing
        return false if unique_firing_violated?(rule_context)
        return rule_context if criteria.blank?  # Rule will fire...
        # TODO: add rescue
        result = eval(criteria, rule_context.get_binding) unless skip_criteria_check
        if skip_criteria_check || result
          puts "...criteria either passed or skipped[#{skip_criteria_check}]"
          rule_context
        else
          nil
        end
      end
    end

    def _check_criteria(rule_event, skip_criteria_check, extras)
      puts "...checking criteria..."
      return false if events.blank? 
      if rule_event[:type] == "TimerEvent"
        timer_event = get_timer_event
        return false unless timer_event
        puts "Detected TimerEvent for rule: #{timer_event}"
        return false unless run_timer?

        rule_event[:timer_event] = timer_event
        klazz = get_timer_event_class 
        if klazz
          puts "Expecting results of type #{klazz} for TimerEvent selection logic: [#{criteria}]"
          #results = klazz.constantize.where(criteria.presence || "id is not null")
          results = begin 
            Array(eval( criteria ))
          rescue => e 
            puts "  Encountered exception running selection logic: #{e.message}"
            puts e.backtrace
            []
          end
          puts "Got #{results.count} results in check_criteria for TimerEvent"
          if results.count > 0
            rc = Rules::Rule.rule_context(rule_event, extras.merge({multiple_triggers: results}))
            return rc
          else
            puts "Returning false due to TimerEvent with criteria returning no results"
            return false
          end
        else
          puts "Returning nil due to TimerEvent with no klazz match"
          return false
        end
      else
        # But if it's a ControllerEvent, do not check if we are mapped to ApplicationController::*
        if rule_event[:type] != "ControllerEvent" || events.index("ApplicationController::*").nil?
          # Make sure the right type of event fired
          unless events.index("#{rule_event[:klazz]}::#{rule_event[:action]}")
            puts "   returning false from check_criteria as #{events} do not include #{rule_event[:klazz]}::#{rule_event[:action]}"
            return false
          end
        end
      end
      Rules::Rule.rule_context(rule_event, extras)
    end

    # Returns true if this rule has already fired for the unique_expression for the given rule_context
    # Examples:
    #    "User_#{trigger.user.id}"                            Fire once per user 
    #    "User_#{trigger.user.id}_#{Time.now.year}"           Fire once per user per year
    #    "User_#{trigger.user.id}_#{Time.now.strftime('%D')}" Fire once per user per day
    #
    def unique_firing_violated?(rule_context)
      return false if unique_expression.blank?
      unique_expr_evaluated = eval(unique_expression, rule_context.get_binding)
      found = Rules::UniqueRuleFiring.find_by_rule_id_and_unique_expression(self.id.to_s, 
        unique_expr_evaluated)
      if found.present?
        Rails.logger.warn "Rule[#{self.id}] has already fired for #{unique_expr_evaluated} - unique_firing_violated? returning true" 
        return true
      else
        return false
      end
    rescue => e 
      Rails.logger.error "Error attempting to evaluate unique_expression[#{unique_expression}] for rule[#{self.id}]"
      return false 
    end

    def mark_unique_fired(rule_context) 
      return if unique_expression.blank?
      unique_expr_evaluated = eval(unique_expression, rule_context.get_binding)
      Rails.logger.info("Marking unique fired rule_id[#{self.id.to_s}] unique_expression[#{unique_expr_evaluated}]")
      found = Rules::UniqueRuleFiring.create(rule_id: self.id.to_s, 
                                                unique_expression: unique_expr_evaluated,
                                                fired_at: Time.current)
    rescue => e 
      Rails.logger.warn("Unable to mark_unique_fired: #{e.message}")
    end

    def validate_criteria_before_save
      result, problems = validate_criteria(self.criteria, false) 
      if problems.present?
        errors.add(:criteria, problems.join("\n"))
      end
    end

  def validate_criteria(c = self.criteria, eval_criteria = false)
    return [] if c.blank?
    problems = []
    Rails.logger.info "Validating criteria: [#{c}]"
    problems << check_matching(c, "[", "]")
    problems << check_matching(c, "{", "}")
    problems << check_matching(c, "(", ")")
    problems << "Cannot have exit in script" if c.scan(/exit/).length > 0
    problems.compact!
    if problems.blank? && eval_criteria && can_validate_criteria?
      begin 
        current_user = Thread.current[:user] || User.new
        actor = current_user      
        klazz = events.first.split("::")[0..-2].join("::").constantize rescue nil 
        if klazz.present?
          trigger = klazz.new 
          if User === trigger 
            trigger = current_user 
          else
            if trigger.respond_to? :user 
              trigger.user = current_user 
            end
          end
        end
        result = eval(c)
      rescue Exception => e 
        problems << "Error evaluating: #{e.message}"
      end
    end

    Rails.logger.info "Validation results: #{problems}"
    [result, problems.compact]
  end

  def can_validate_criteria?
    true
    #["create", "update", "destroy"].include? events.first.split("::").last 
  end

  def check_matching(str, opening, closing) 
    # make sure occurrences of opening and closing are equal in number
    if ["[","{","("].include? opening
      # need escape character in our regexp
      c1 = str.scan(Regexp.new( "\\#{opening}")).length rescue 0
      c2 = str.scan(Regexp.new( "\\#{closing}")).length rescue 0
    else
      c1 = str.scan(/#{opening}/).length rescue 0
      c2 = str.scan(/#{closing}/).length rescue 0
    end
    (c1 == c2) ? nil : "Mismatched nestings: #{c1} occurrences of '#{opening}' and #{c2} occurrences of '#{closing}'"
  end


    # returns true if passed path is valid within the scope of this rule
    def validate_context_path(path)
      parts = path.split(".")
      context_entry_point = parts[0]
      return false unless self.context[context_entry_point]
      field = (parts.length > 1) ? parts.pop : nil
      base_path = parts.join(".")
      possible_fields = lookup_path(base_path) 
      return (field.blank?) ? true : !!possible_fields[field.to_sym]
    end

    def get_context_path_type(path)
      return "User" if path == "actor"
      return "trigger" if path == "trigger"
      parts = path.split(".")
      context_entry_point = parts[0]
      return false unless self.context[context_entry_point]
      field = (parts.length > 1) ? parts.pop : nil
      base_path = parts.join(".")
      possible_fields = lookup_path(base_path) 
      return (possible_fields[field.to_sym] || "").split("::").last
    end

    # called like : lookup_path("trigger")
    #          or : lookup_path("trigger.user")
    def lookup_path(path, sub_context = nil)
      return context if (path.blank? || path == "/") && !sub_context   # Default for retrieving root context path
      # path = "trigger.user"    parts[0]="trigger"  parts[1]="user"
      parts = path.split(".")
      if sub_context.nil?
        if parts.first == "actor"
          parts.shift
          path=parts.join(".")
          klazz = User
          return lookup_path(path, User) unless path.blank?
        elsif parts.first == "trigger"
          parts.shift
          path=parts.join(".")
          cols = nil
          if scheduled?
            sub_cols = lookup_path(path, get_timer_event_class.constantize)
            cols = sub_cols
          else
            # We need to get all the possible path values from all the input events
            events.each do |event|
              cfg = Rules::RulesConfig.event_config(event)
              case cfg[:type]
              when "ModelEvent", "ControllerEvent"
                klazz = (event.split("::")[0...-1].join("::")).constantize    # Strip off the trailing action: create, update, delete, etc...
              when "ApplicationEvent" 
                klazz = cfg[:context]["trigger"].camelcase.constantize
              end
              puts klazz
              sub_cols = lookup_path(path, klazz)
              puts sub_cols
              cols ||= sub_cols
              # This will perform an intersection across all the event fields 
              cols.each do |k,v|
                unless sub_cols[k]==v
                  puts "Removing due to intersection #{k}"
                  cols.delete k
                end
              end
            end
          end
          puts "Returning"
          puts cols
          return cols
        end
      end
      klazz ||= sub_context || self
      cols = {}
      if parts.length == 0
        cols = Rules::Rule.get_columns(klazz)
      else
        found = false
        if klazz.respond_to? :reflect_on_all_associations
          (klazz.reflect_on_all_associations(:has_one) +
          klazz.reflect_on_all_associations(:belongs_to)).each do |assoc| 
            if (assoc.name.to_s == parts.first)
              found = true
              if assoc.options[:polymorphic]
                # We have a polymorphic relationship going on here...we will:
                #   1) Find all the possible Polymorphic targets
                #   2) Take an intersection of their properties
                #
                # This is awesome because if MessageRecipient, for example, has a belongs_to polymorphic property called: recipient, 
                # and if there are 3 other classes that have a 
                #        has_many :something, class_name: PyrCrm::MessageRecipient, as: :recipient
                # it will find those 3 classes and intersect their respective columns to get the safely mapped column list.
                #
                ed = Rules::EventConfigLoader.events_dictionary
                polymorphs = []
                ed[:model_events].keys.each do |candidate_class|
                  begin
                    klass = candidate_class.constantize
                    klass.reflect_on_all_associations(:has_many).select{|r| r.options[:as] }.each do |reflection|
                      if reflection.options[:as].to_s == path 
                        # We found a possible 
                        polymorphs << klass
                      end
                    end
                  rescue NameError => e 
                    logger.warn("Unable to reflect upon #{candidate_class} : #{e.message}")
                  end
                end
                # Loop through all Polymorphic classes and intersect their columns
                polymorphs.each do |pm| 
                  new_cols = Rules::Rule.get_columns(pm)
                  puts "Polymorphic columns for #{pm} : #{new_cols}"
                  if cols.size == 0
                    cols = new_cols
                  else
                    cols.keys.each do |key|
                      cols.delete(key) unless new_cols[key]
                    end
                  end
                end
                return cols if cols.size > 0              
              end
              parts.shift
              path=parts.join(".")
              klazz = assoc.klass
              return lookup_path(path, klazz)
            end
          end
        end
      end
      # raise "Invalid path [#{path}]" if !found && cols.blank? # Not valid logic here - sandboxed
      cols
    end

    def self.get_columns(klazz)
      cols = {}
      if klazz.respond_to? :reflect_on_all_associations
        (klazz.reflect_on_all_associations(:has_one) +
        klazz.reflect_on_all_associations(:belongs_to)).each do |assoc| 
          klass_type = assoc.options[:class_name].to_s.presence || assoc.name.to_s
          klass_type = klass_type[2..-1] if ( klass_type.starts_with?("::")) 
          puts klass_type            
          cols[assoc.name.to_sym] = klass_type
        end
      end
      Rules::ContextFields.for_class(klazz).each do |name, info|
        cols[name.to_sym] = info[:type].to_sym
      end

      if klazz.respond_to? :columns   # ActiveRecord
        klazz.columns.each{|c| cols[c.name.to_sym] ||= c.type.to_sym }
      end

      if klazz.respond_to? :fields    # Mongoid
        fields.each{|k,v| cols[v.name.to_sym] ||= v.options[:type].name.downcase.to_sym }
      end
      cols
    end

    def d3_actions_map
      actions.map do |a| 
        {name: a.type, id: a.type, children: []}
      end
    end


    def joint_map
      { events: events,
        id: self.id.to_s,
        ready: ready?,
        synchronous: self.synchronous?,
        name: self.name,
        criteria: self.criteria, 
        actions: actions.map do |a| 
          { name: a.type.split("::").last, id: a.id.to_s, active: a.active, ready: a.ready?, 
            defer_processing: a.defer_processing?, scheduled: a.scheduled? }
        end 
      }
      
    end

    #   
    #   This keeps a stack of rule ids in scope so as to prevent the same rule firing
    #   multiple times during a single event-action-chain
    # 
    def self.processing_stack
      Thread.current[:processing_stack] ||= []
    end

    # Clears the processing stack completely
    def self.processing_stack_clear
      Thread.current[:processing_stack] = []
    end

    # Makes sure the passed rule_ids are all on the stack
    #
    # Returns: only the rule_ids that were not already in scope
    def self.processing_stack_add(rule_ids)
      stack = processing_stack
      added_rule_ids = []
      rule_ids.each do |rule_id|
        next if stack.index(rule_id) 
        added_rule_ids << rule_id
      end
      stack.push(*added_rule_ids)
      added_rule_ids
    end

    # Removes an explicitly passed in list of rule_ids to be removed  
    # This should be the same list of rule_ids that was RETURNED from processing_stack_add
    #
    # Returns: the stack after removing the passed rule_ids
    def self.processing_stack_remove(rule_ids)
      stack = processing_stack
      rule_ids.each do |rule_id|
        stack.delete rule_id
      end if rule_ids
      stack
    end

    # timer_expression must start with either "cron:" or "every:" 
    # this returns a duple [every, cron]
    def parse_timer_expression
      return [nil,nil] unless self.timer_expression.present? 
      parts = self.timer_expression.split(":")
      case parts[0]
      when "cron" 
        [nil, parts[1].squish]
      when "every" 
        [parts[1].squish, nil]
      else
        [nil,nil]
      end
    end

    private

      def set_schedule
        if scheduled? && active? && !rule_deleted?
          Rails.logger.info "Setting schedule: #{_schedule_name}"
          Resque.set_schedule _schedule_name, _build_schedule_config
        else
          remove_schedule 
        end
      rescue => e 
        Rails.logger.error "Error setting schedule for Rule[#{self.id.to_s}]: #{e.message}"        
      end

      def remove_schedule
        return unless Resque.fetch_schedule(_schedule_name)
        Rails.logger.info "Removing schedule: #{_schedule_name}: scheduled?[#{scheduled?}]  active?[#{active?}]  _deleted?[#{_deleted?}]"
        Resque.remove_schedule _schedule_name
      rescue => e 
        Rails.logger.error "Error removing schedule for Rule[#{self.id.to_s}]: #{e.message}"        
      end

      def _build_schedule_config
        config = {} 
        config[:description] = self.name 
        every, cron = parse_timer_expression
        config[:every] = every
        config[:cron] = cron 
        config[:class] = "Rules::Jobs::RunScheduledRule"
        config[:args] = [self.id.to_s] 
        config[:persist] = true
        Rails.logger.info "   schedule options: #{config}"
        config
      end

      def _schedule_name 
        "Rule_#{self.id}"
      end

      def set_synchronous
        required_synchronous = false
        actions.each do |a|
          if a.synchronous?
            puts "--- Marking Rule[#{self.name}] as Synchronous cuz #{a.type} requires synchronous processing"
            required_synchronous = true 
          end
        end
        puts "--- Marking Rule[#{self.id} #{self.name}].synchronous = #{required_synchronous} while system processing is set to [#{Rules.event_processing_strategy}]"
        self.synchronous = required_synchronous 
        true # don't accidentally return false - it will halt the saving procedure
      end

      def context_mapping_sanity_check
        actions.each do |a| 
          a.context_mapping_sanity_check 
        end
        return true # don't accidentally return false - it will halt the saving procedure
      end

      def temp_migrate_deleted
        if (previously_deleted = self["deleted"])
          self["deleted"] = nil
          self._deleted = true 
        end
      end
  end
end





