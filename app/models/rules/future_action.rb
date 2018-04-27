# == Schema Information
#
# Table name: rules_future_actions
#
#  id                   :integer          not null, primary key
#  run_at               :datetime
#  contingent_script    :string(255)
#  run_at_expression    :string(255)
#  unique_expression    :string(255)
#  recurring_expression :string(255)
#  rule_id              :string(255)
#  action_id            :string(255)
#  action_handler       :string(255)
#  context_mapping      :string(2000)
#  template             :string(6000)
#  event                :text(65535)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  priority             :integer          default(0)
#  unique_id            :string(255)
#  processed_at         :datetime
#

# t.datetime :run_at                # when SHOULD this run
# t.datetime :processed_at          # when DID this run?
# t.integer :priority								# higher number equals higher priority, default: 0
# t.string :contingent_script       # only actually run if this is still true 
# t.string :run_at_expression       # an expression used to determine the :run_at time
# t.string :unique_expression       # an expression used to determine the :unique_expression
# t.string :recurring_expression
# t.string :unique_id									# computed from :unique_expression - in case *THIS* has already happened
# t.string :rule_id                   # The Rule that gave rise to this FutureAction
# t.string :action_id                 # The Action within the Rule that gave rise to this FutureAction
# t.string :action_handler                # action.type
# t.string :context_mapping               # action.context_mapping
# t.string :template                      # action.template
# t.text :event                           # event ( will contain actor(user), trigger( klazz/id ), data(previous state of trigger) )

# Some thoughts about FutureActions:
#
#    - Reminders should be high priority - it does no good to be reminded after an event has occurred...
#    - Once processed, let's move the records into FutureActionArchive
#
class Rules::FutureAction < ActiveRecord::Base
  serialize :event, Hash

  
  def table_name_prefix
        Rules.table_name_prefix
  end
      
  # Suppose that a FutureAction was created at some point and now we have a reference to it.
  # Also suppose that we want to run the FutureAction...
  #
  # Well, FutureAction#run_now is just what you're looking for!
  #
  # Unless it has already been run (processed_at.present?), then you can probably run the
  #   FutureAction by calling run_now
  def run_now
    Rails.logger.info "Running FutureAction[#{id}]"
    if processed_at.present?
      Rails.logger.info "   ALREADY PROCESSED - NOOP"
      return
    end
    r = Rules::Rule.find(self.rule_id)
    a = r.actions.find(self.action_id)
    rule_context = Rules::Rule.rule_context(self.event, running_future_action: true)
    a.process_action(self.event, rule_context, [])
    self.processed_at = Time.current 
    self.save!
  rescue e 
    Rails.logger.error "Error running FutureAction[#{id}]"
    Rails.logger.error e.backtrace.join("\n")
  ensure
    Rails.logger.info "Finished FutureAction[#{id}]"
  end

  # Returns the next batch of FutureActions to run within the next Time window...
  def self.next_batch(time_window = 1.minute)
    run_these = Rules::FutureAction.where("processed_at is null and run_at <= ?", 
                                                time_window.from_now).order("run_at ASC")
    Rails.logger.info("  Retrieved next batch of FutureActions - size #{run_these.size}")
    run_these
  end

  def self.run_next_batch(time_window = 1.minute) 
    Rails.logger.info("  Running next batch of FutureActions with time_window = #{time_window}")
    run_these = next_batch(time_window) 
    run_these.each do |future_action| 
      future_action.run_now
    end
  end
end
