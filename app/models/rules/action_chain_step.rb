# == Schema Information
#
# Table name: rules_action_chain_steps
#
#  id                       :integer          not null, primary key
#  deferred_action_chain_id :integer
#  waiting_on_type          :string(255)
#  waiting_on_id            :integer
#  step_number              :integer
#  continuation_strategy    :string(255)
#  continued_at             :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

# t.integer :deferred_action_chain_id
# t.string :waiting_on_type
# t.integer :waiting_on_id
# t.integer :step_number
# t.datetime :continued_at
# t.string :continuation_strategy

class Rules::ActionChainStep < ActiveRecord::Base

	belongs_to :waiting_on, polymorphic: true
	belongs_to :deferred_action_chain

	def continue
		puts "\n\nActionChainStep.continue: Continuing processing of DeferredActionChain\n"
		self.continued_at = Time.now
		self.save!
		deferred_action_chain.resume_processing
	end


end
