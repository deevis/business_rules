class AddPriorityToFutureActions < ActiveRecord::Migration
  def change
    add_column :rules_future_actions, :priority, :integer, default: 0
    add_column :rules_future_actions, :unique_id, :string							
    rename_column :rules_future_actions, :uniq_expression, :unique_expression
  end
end