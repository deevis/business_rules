class AddProcessedAtToFutureActions < ActiveRecord::Migration[5.0]
  def change
    add_column :rules_future_actions, :processed_at, :datetime
  end
end