require "rules/engine"

module Rules

  @@queue_counter ||= 0

  mattr_accessor :table_name_prefix
  @@table_name_prefix ||= "pyr_"

  mattr_accessor :trash_icon
  @@trash_icon ||= "ic-icon-trash"         #   icon-trash

  mattr_accessor :delete_icon
  @@delete_icon ||= "ic-icon-times-circle"       # icon-remove

  mattr_accessor :arrow_icon
  @@arrow_icon ||= "ic-icon-arrow-right"   # icon-arrow-right

  mattr_accessor :lookup_icon
  @@lookup_icon ||= "ic-icon-search"       # icon-search
  
  mattr_accessor :clock_icon
  @@clock_icon ||= "ic-icon-clock"       # icon-search
  
  mattr_accessor :rules_categories 
  @@rules_categories ||= ["Uncategorized"]

  # Should we automatically stitch ModelEventEmitter into ActiveRecord::Base
  mattr_accessor :active_record       
  @@active_record ||= true

  # If you are using non-standard table mappings (if you use table_name_prefix), then you may
  # need to actively load your classes here
  mattr_accessor :development_model_paths
  @@development_model_paths ||= []

  mattr_accessor :event_processing_strategy
  @@event_processing_strategy

  mattr_accessor :redis_host
  @@redis_host ||= "localhost"

  mattr_accessor :redis_port
  @@redis_port ||= 6379

  mattr_accessor :redis_queue_name
  @@redis_queue_name ||= "events_queue"

  mattr_accessor :logging_level
  @@logging_level ||= :info

  # The application using Rules can add their own events in here for use in Rules
  mattr_accessor :application_events
  @application_events ||= []

  mattr_accessor :disallow_web_redirects_from 
  @disallow_web_redirects_from ||= 'sign_out|heartbeat'


  # Allow for mappings between different types of objects
  mattr_accessor :context_mapping_equivalencies
  @@context_mapping_equivalencies ||= {}

  # Set rule_activity_channel to have push notifications go to Rules admin screen
  mattr_accessor :rule_activity_channel
  @@rule_activity_channel ||= nil

  mattr_accessor :rule_activity_channel_enabled
  @@rule_activity_channel_enabled ||= false

  mattr_accessor :flush_rules_event_analytics_every
  @@flush_rules_event_analytics_every ||= 10000

  mattr_accessor :flush_rules_action_analytics_every
  @@flush_rules_action_analytics_every ||= 10000

  mattr_accessor :flush_rules_rule_analytics_every
  @@flush_rules_rule_analytics_every ||= 10000

  # TODO: not implemented - These are run prior to each Rule evaluation
  mattr_accessor :before_filter_procs
  @@before_filter_procs ||= [] 

  # TODO: not implemented - These are run after each Rule evaluation
  mattr_accessor :after_filter_procs
  @@after_filter_procs ||= [] 




  # instance_lookups is a mapping of <exepected_field_type> => <allowed_classes>
  #
  # Allowed classes should be either hash of classnames or the symbol :model_events which means to use all classes mapped as model events
  #
  # When a hash of classnames is used, the classname is the key, and the value is a nested hash with keys :search and :display
  # 
  #   :search is an array of properties to show and use when searching for instances
  #   :display is a templated string to be evaluated for each instance when displaying them
  #
  # eg: (in a client initializer)
  #
  # config.instance_lookups[:messaging_user] = {  "User": {
  #                                                 search: [:username, :consultant_id],
  #                                                 display: '"#{display_name}  [#{username}]"'
  #                                               },
  #                                               "TreeUser": {
  #                                                 search: [:consultant_id],
  #                                                 display: '"#{display_name}  [#{consultant_id}]"'
  #                                               }
  #                                             }
  mattr_accessor :instance_lookups
  @@instance_lookups ||= { class_lookup: :model_events,
                         object: :model_events  }


  # Default way to setup Rules
  def self.setup
    yield self
  end

  def self.data_filter
    @@parameter_filter ||= ActionDispatch::Http::ParameterFilter.new Rails.application.config.filter_parameters.try(:uniq)
  end

  def self.set_rule_activity_channel_enabled(enabled)
    _set_rule_activity_channel_enabled(enabled)
    if Rules.respond_to?(:cluster_send) && Rules.event_processing_strategy != :synchronous
      Rules.cluster_send._set_rule_activity_channel_enabled(enabled)
    end
  end

  def self._set_rule_activity_channel_enabled(enabled) 
    Rules.rule_activity_channel_enabled = enabled
  end

  def self.set_logging_level(new_level)
    if Rules.respond_to?(:cluster_send) && Rules.event_processing_strategy != :synchronous
      Rules.cluster_send._set_logging_level(new_level)
    else
      _set_logging_level(new_level)
    end
  end

  def self._set_logging_level(new_level) 
    Rules.logging_level = new_level
  end

  def self.disable!
    puts "Disabling Rules Engine..."
    @@disabled = true 
  end

  def self.disabled? 
    return true if Thread.current[:rules_block_disabled]
    @@disabled ||= false 
  end
  
  def self.enabled?
    !disabled?
  end

  def self.activate_event_processing
    Rules.disable! if ENV['RULES_DISABLED'] == 'true'
    if Rules.disabled? 
      puts "\n\n          Rule processing is disabled - returning now...\n\n"
      return
    end
    if Rules.event_processing_strategy == :synchronous
      # Call the rules engine directly with the event payload
      Rules::RulesEngine.send(:include, Rules::Synchronous)
    elsif Rules.event_processing_strategy == :delayed_job
      # Create delayed_job records to be process the event payload
      raise "If wishes were fishes...we do not yet have the :delayed_job strategy implemented for pyr_event_processing.  Try again later..."
    elsif Rules.event_processing_strategy == :redis
      # Pump event payloads out to a Redis Queue for processing by worker processes
      raise "Please set redis_host and redis_port on Rules to use :redis event_processing_strategy" unless (Rules.redis_host && Rules.redis_port)
      Rules::RulesEngine.send(:include, Rules::Redis)
    else
      raise "Please setup config.event_processing_strategy to one of [:synchronous, :redis] in one of your environment files.  Yes we could just default this value, but this is an important decision - choose wisely!!!"
    end

  end

  # Pass in a block to run without Rules being processed
  def self.with_rules_disabled
    Thread.current[:rules_block_disabled] = true
    yield
  ensure
    Thread.current[:rules_block_disabled] = nil    
  end

end