class CreateRulesFutureActions < ActiveRecord::Migration
  def change
    create_table :rules_future_actions do |t|
      t.datetime :run_at
      t.string :contingent_script
      t.string :run_at_expression
      t.string :uniq_expression
      t.string :recurring_expression
      t.string :rule_id
      t.string :action_id
      t.string :action_handler
      t.string :context_mapping, limit: 2000
      t.string :template, limit: 6000
      t.text :event
      t.timestamps
    end
  end
end
