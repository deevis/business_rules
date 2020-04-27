Rules.setup do |config|
  # Automatically add ModelEventEmitter to all ActiveRecord classes
  config.active_record = true

  # Scan for models to eagerly load in development mode
  config.development_model_paths << "app/models/**/*.rb"

  # config.event_processing_strategy = :synchronous, :redis
  config.event_processing_strategy = :synchronous

  # config.context_mapping_equivalencies = { messaging_user: [:user, :employee, :caller, :recipient, :sender, :string],
  #                                          object: [:user, :messaging_user, :employee, :string],
  #                                          user: [:sender] }

  config.context_mapping_equivalencies = { messaging_user: [:user, :string],
                                           object: [:user, :messaging_user, :string],
                                           user: [:sender] }


  config.current_user = -> {Thread.current[:rules_user]}

  # config.instance_lookups[:messaging_user] = {  "User" => {
  #                                                 search: [:email, :name],
  #                                                 display: '"#{name}  [#{email}]"'
  #                                               }}
  config.instance_lookups[:messaging_user] = {  "User" => {
                                                  search: [:email],
                                                  display: '"#{email}"'
                                                }}

  config.instance_lookups[:user] = {  "User" => {
                                                  search: [:email],
                                                  display: '"#{email}"'
                                                }}

  config.system_messaging_user = "noreply@#{ActionMailer::Base.default_url_options[:host]}"

  # config.event_extensions = ->(h) { h[:agency_id] = Agency.current.try(:id); h }

  # config.rule_context_around = ->(event_hash, &block) { a = Agency.find(event_hash[:agency_id]); Agency.with(a) { block.call if block} }

  # config.redis_host, config.redis_port = ["localhost", 6379]
  # config.redis_queue_name = "rules_events"

end

# Add middleware to make Redirect Rules work
require 'rules/all'
require 'rules/middleware/redirect_rule'

# require our custome rules handlers
# require "create_notification"
# require "create_task"
# require "track_activity"


Rules.activate_event_processing #unless Rails.env == "test"
# Rails.configuration.middleware.use "Rules::Middleware::RedirectRule"
