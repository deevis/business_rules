class CreateRulesFutureActions < ActiveRecord::Migration
  def change

    create_table :rules_rules do |t|
      t.string :name
      t.string :description
      t.string :category, default: "Uncategorized"
      t.string :criteria
      t.string :definition_file
      t.json :events
      t.boolean :synchronous, default: false
      t.boolean :active, default: true
      t.string :unique_expression
      t.datetime :start_time
      t.datetime :end_time
      t.json :timer
      t.string :timer_expression
      t.string :event_inclusion_matcher
      t.string :event_exclusion_matcher
      t.json :updated_actions
      t.datetime :deleted_at, index: true
      t.timestamps
    end

    create_table :rules_actions do |t|
      t.string :title
      t.string :action_type
      t.integer :ordering
      t.references :rule, foreign_key: {to_table: 'rules_rules'}, index: true
      t.json :context_mapping
      t.json :template
      t.json :future_configuration
      t.boolean :active, default: true 
      t.boolean :defer_processing, default: false
      t.timestamps
    end

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
