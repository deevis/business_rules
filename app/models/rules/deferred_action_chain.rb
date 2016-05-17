    # create_table :rules_deferred_action_chains do |t|
    #   t.string :rule_id
    #   t.string :path 
    #   t.text :event
    #   t.text :action_chain_results
    #   t.timestamps
    #  	t.datetime :completed_date
    # end

class Rules::DeferredActionChain < ActiveRecord::Base
  serialize :event, Hash
  serialize :action_chain_results, Array

  has_many :action_chain_steps

  def table_name_prefix
    Rules.table_name_prefix
  end
      
  def rule
  	Rules::Rule.find rule_id
  end

  # Calling resume_processing will attempt to re-instantiate the original Rules ActionChain and continue processing 
  def resume_processing
    puts "\nDeferredActionChain.resume_processing: Resuming processing of DeferredActionChain[#{self.id}] of Rule #{self.rule_id}\n"
    rule.process_rule(event, self)
  end

  def set_next_step(continuation_strategy, action_chain_results)
    puts "DeferredActionChain[#{self.id}].set_next_step"
    waiting_on = action_chain_results.last   # The last result is the one that will be associated to a ContinuationStrategy
    self.action_chain_results = action_chain_results 
    puts "   - creating new ActionChainStep record waiting on #{waiting_on.class}[#{waiting_on.id}]"
    self.action_chain_steps.create( continuation_strategy: continuation_strategy, 
                                    waiting_on: waiting_on, 
                                    step_number: action_chain_results.size)   # 1-endian to be consistent with UI and other code
    self.save!
    puts "   - finished set_next_step\n"
  end

end
