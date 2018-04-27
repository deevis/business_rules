# This migration comes from rules_engine (originally 20140824315457)
class CreateRulesActionChainSteps < ActiveRecord::Migration[5.0]
  def change
    create_table :rules_action_chain_steps do |t|
      t.integer :deferred_action_chain_id
      t.string :waiting_on_type
      t.integer :waiting_on_id
      t.integer :step_number
      t.string :continuation_strategy
      t.datetime :continued_at
      t.timestamps
    end

    add_index :rules_action_chain_steps, [:waiting_on_type, :waiting_on_id], name: "idx_rules_action_chain_waiting_on"    
    add_index :rules_action_chain_steps, [:continuation_strategy]    
    
  end
end
