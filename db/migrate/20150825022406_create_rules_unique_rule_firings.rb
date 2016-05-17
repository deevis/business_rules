class CreateRulesUniqueRuleFirings < ActiveRecord::Migration
  def change
    create_table :pyr_unique_rule_firings do |t|
      t.string :rule_id
      t.string :unique_expression
      t.datetime :fired_at
    end

    add_index :pyr_unique_rule_firings, [:rule_id, :unique_expression], 
              name: "idx_pyr_unique_rule_firings", unique: true
  end
end
