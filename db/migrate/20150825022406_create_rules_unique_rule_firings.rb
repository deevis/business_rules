class CreateRulesUniqueRuleFirings < ActiveRecord::Migration
  def change
    create_table :rules_unique_rule_firings do |t|
      t.string :rule_id
      t.string :unique_expression
      t.datetime :fired_at
    end

    add_index :rules_unique_rule_firings, [:rule_id, :unique_expression], 
              name: "idx_rules_unique_rule_firings", unique: true
  end
end
