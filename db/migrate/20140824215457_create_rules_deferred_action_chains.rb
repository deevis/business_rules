class CreateRulesDeferredActionChains < ActiveRecord::Migration
  def change
    create_table :pyr_deferred_action_chains do |t|
      t.string :rule_id
      t.string :path 
      t.text :event
      t.text :action_chain_results
      t.datetime :completed_date
      t.timestamps
    end

    add_index :pyr_deferred_action_chains, :rule_id    
  end
end
