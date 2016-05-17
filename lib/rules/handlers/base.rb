require 'active_support'
require "active_support/core_ext"

  module Rules
    module Handlers
      class Base
        # Reserved words that cannot be used by either needs or templates include:
        # 
        #  :action
        #  :actor
        #  :trigger
        #
        # needs is a map of required fields for each and every type of ActionHandler
        #
        @@_needs ||= {}
        
        # @@action_configuration will be a Hash with classes as keys and needs and templates 
        #  {  
        #    PyrCore::Handlers::Email=>
        #      {:needs=>{:recipient=>:messaging_user, :sender=>:messaging_user}, :templates=>{:subject=>"", :body=>""}},
        #    PyrCore::Handlers::ActivityStream=>
        #      {:needs=>{:actor=>:user, :trigger=>:object}, :templates=>nil},
        #    PyrCore::Handlers::Notification=>
        #      {:needs=>{:recipient=>:messaging_user, :trigger=>:object}, :templates=>nil}
        #  }
        @@action_configuration = nil
        @@templates ||= {}

        class_attribute :continuation_strategy
        class_attribute :synchronous
        class_attribute :testable

        # Set this if your Action class can defer the processing of the Action chain
        def self.set_continuation_strategy(val)
          self.continuation_strategy = val
        end

        # Set this if your Action should always be run synchronously
        def self.set_synchronous(value=true)
          self.synchronous = value
        end
        
        # Set this if your Action can be tested realtime via the designer tools
        def self.set_testable(value=true)
          self.testable = value
        end
        
        # # If a continuation_strategy is set, then this handler may halt processing of Rule's Actions
        # def self.continuation_strategy(klass=nil)
        #   if klass
        #     # TODO: Check this is a valid strategy
        #     self.continuation_strategy = klass
        #   end
        #   self.continuation_strategy
        # end

        def self.needs(name, type=:string, options = {})
          @@_needs[self.name] ||= {}
          @@_needs[self.name][name] = {type: type}.merge(options)
          options.each do |k,v|
            @@_needs[self.name][name][k] = v
          end
        end

        # def self.needs_map
        #   @@needs[self]
        # end

        # Return the template with provided name for the calling subclass 
        def self.template(name, opts={})
          @@templates[self.name] ||= {}
          @@templates[self.name][name] = (block_given?) ? yield : ""
        end

        # Return the list of templates for the calling subclass
        def self.templates 
          (@@templates[self.name] || {}).keys
        end

        attr_accessor :event, :action
        def initialize(action, event, rule_context = nil, action_chain_results = [])
          unless action.class.name == "Rules::Action"
            raise "Invalid argument exception : expected [Rules::Action] but got [#{action.class}]"
          end
          @action = action  # Allow use of symbols or strings as keys    trigger = event_hash[:klazz].constantize.find event_hash[:id].to_i rescue nil
          @event = event
          @action_chain_results = action_chain_results 
          @context = rule_context || Rules::RuleContext.new(event || {})
        end

        def handle
          puts "  HANDLE called for #{@event.inspect}\n  #{@action.inspect}"
          set_default_market
          return _handle  # needs to be provided by subclass
        rescue => e 
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")
        ensure
          clear_default_market
        end

        def set_default_market(user = nil)
          Rails.logger.info "\n\n     set_default_market"
          if user.present? && defined?(PyrCrm::MessagingUser) && !user.is_a?(PyrCrm::MessagingUser)
            # if we have a string being passed in, for example, then we don't have a user that we can derive Market from...
            Rails.logger.warn("Disregarding passed user of type #{user.class} for use as MarketProvider")
            user = nil
          end
          if user.blank?
            user = self.cms_market_user
            Rails.logger.info("Used Action#cms_market_user") if user.present?
          end

          if defined?(::User) && user.blank? && trigger.present? 
            if trigger.is_a?(::User)
              user = trigger 
              Rails.logger.info("Using Trigger as MarketProvider: User[#{user.id}]")
            elsif trigger.respond_to?(:user) 
              user = trigger.user
              Rails.logger.info("Using trigger.user as MarketProvider: User[#{user.id}]")
            end
          end
          if user.blank? && actor.present?
            user = actor 
            Rails.logger.info("Using the Actor as the MarketProvider: User[#{user.id}]")
          end
            
          if user.present?
            if defined?(::User) && !user.is_a?(::User) 
              Rails.logger.warn("  user[#{user.class}] is not of type User...panicking a bit")
              # If we know about Users but the user instance is NOT a user
              if user.respond_to?(:user)
                # then let's get the linked user record (think PyrTree::User and PyrCrm::Contact)
                user = user.user 
                Rails.logger.info("  sigh of relief, using the linked user method: User[#{user.id}]")
              else 
                # we don't know how to set the user here
                Rails.logger.error("  panick state realized - unsetting user and Market will be Global")
                user = nil 
              end
            end
          end
        end


        def self.display_name_details(action)
          ""
        end


        # If a subclass is marked testable, then this will help build the test context for that rule to run
        def self.test_context(for_action)
          dummy_context_fields = []
          templates.each do |t|
            fields = for_action.template_fields(t, include_interpolated: true)
            fields.each_with_index do |field, idx|
              if field.index(".") 
                # this was interpolated - change it to normal - DO NOT SAVE ACTION AFTER!!!
                for_action.template_body(t).gsub!(field, "interpolated_#{t.to_s}_#{idx}")
                dummy_context_fields << "interpolated_#{t.to_s}_#{idx}"
              else
                dummy_context_fields << field
              end
            end
          end
          dummy_context = {}
          dummy_context_fields.each_with_index do |field, index|
            dummy_context[field] = "[Test #{index+1}]"
          end
          puts "Using DummyContext: \n#{dummy_context}"
          puts "To test Action: \n#{for_action.to_json}"
          Rules::RuleContext.new(dummy_context)
        end

        # Contains a stack of all the previous actions' results
        def action_chain_results
          @action_chain_results
        end

        def self.reload_configuration
          puts "Reloading ActionHandler configuration"
          @@action_configuration = nil
          configuration
          @@action_configuration.keys
        end

        def self.configuration
          return @@action_configuration[self.name] if @@action_configuration
          @@action_configuration = {}
          puts "...scanning for Action Handlers!!!\n"
          #if Rails.env.development?
              Dir["#{Rails.root}/../**/*/app/**/handlers/*.rb"].each do |p| 
                puts "require #{p}" 
                require_dependency p
              end
          #end
          _add_needs_and_recurse(Rules::Handlers::Base)
          @@action_configuration[self.name]
        end

        def self.action_listing
          configuration # force load
          @@action_configuration.keys
        end

        def self._add_needs_and_recurse(klazz)
          klazz.subclasses.each do |c| 
            @@action_configuration[c.name] ||= {}
            @@action_configuration[c.name][:needs] = @@_needs[c.name]
            @@action_configuration[c.name][:templates] = @@templates[c.name]
            _add_needs_and_recurse(c)
          end
        end

        # Returns a key-sorted map of simple action name keys with values being the full-blown class
        # {
        #     "ActivityStream" => "PyrCore::Handlers::ActivityStream",
        #     "CreateModel"=>"Rules::Handlers::CreateModel",
        #     "WebRequestLogger"=>"Rules::Handlers::WebRequestLogger"
        # }
        def self.sorted_action_lookup_map
          {}.tap do |c| 
            Rules::Handlers::Base.action_listing.sort do |a,b| 
              a.split("::").last <=> b.split("::").last
            end.map {|a| c[a.split("::").last] = a}
          end
        end

        # Our context methods will be accessible through here
        def method_missing(meth, *args, &block)
          need_configuration = @action.needs[meth]
          if need_configuration
            mapping_type = need_configuration[:type]
            rule_field, rule_type = @action.lookup_context_mapping(meth, mapping_type)
            # if this is an instance_lookup, well do that here...
            value = if rule_type == "instance_lookup"   
              puts "Evaluating dynamic action need via instance_lookup : [#{rule_field}]"
              @action.instance_lookup(rule_field)
            elsif rule_type == "class_lookup" 
              puts "Evaluating dynamic model creation via class_lookup : [#{rule_field}]"
              rule_field.camelcase.constantize
            elsif rule_type == "free_form" && (!rule_field.squish.start_with?("->"))
              rule_field
            elsif rule_type == "free_form" && (rule_field.squish.start_with?("->"))
              puts "Evaluating free_form lambda : [#{rule_field}]"
              result = eval(rule_field).call
              puts "Lambda evaluated to: #{result}"
              result
            elsif rule_type == "lambda_lookup"
              puts "Evaluating lambda_lookup : [#{rule_field}]"
              lambda_expr = Rules.instance_lookups[mapping_type][:lambda_lookup][:predefined][rule_field.to_sym]
              puts "Evaluating lambda_lookup : [#{lambda_expr}]"
              eval(lambda_expr).call
            else
              puts "Evaluating dynamic action need via rule_context: [#{rule_field}]"
              eval (rule_field || meth.to_s), @context.get_binding rescue nil              # Set in initialize
            end
            puts "DEBUG: Rules::Handler::Base.method_missing(#{meth}) evaluated to : #{value}"
            if value.nil? && need_configuration[:default].present?
              value = need_configuration[:default]
              puts "Using default value: #{value}"
            end
            return value
          else
            puts "Attempting to evaluate interpolated value via rule_context: [#{meth.to_s}]"
            eval meth.to_s, @context.get_binding rescue nil                 # Set in initialize
          end
        end


        def eval_template(template_name)
          template_name = template_name.to_s
          puts "    DEBUG: Looking up #{template_name} from #{@action.template}"
          t = @action.template_body(template_name)
          raise "Tombstone Encountered, not running Action" if t.present? && t == :rip
          t = t.to_s.clone
          interpolated_fields = @action.template_fields(template_name, include_interpolated: true)
          interpolated_fields.each do |f|
            t.gsub!("{#{f}}","\#{#{f}}")
          end
          t.gsub!('"', '\"')
          t.gsub!("'", "\'")
          puts "    DEBUG: Using #{t}"
          result = eval '"' + t + '"'
          puts "    DEBUG: Evaluated to : #{result}"
          result
        end
      end
    end
  end
