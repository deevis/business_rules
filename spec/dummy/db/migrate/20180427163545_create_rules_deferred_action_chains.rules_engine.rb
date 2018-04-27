# This migration comes from rules_engine (originally 20140824215457)
class CreateRulesDeferredActionChains < ActiveRecord::Migration[5.0]
  def change
    create_table :rules_deferred_action_chains do |t|
      t.string :rule_id
      t.string :path 
      t.text :event
      t.text :action_chain_results
      t.datetime :completed_date
      t.timestamps
    end

    add_index :rules_deferred_action_chains, :rule_id    
  end
end
