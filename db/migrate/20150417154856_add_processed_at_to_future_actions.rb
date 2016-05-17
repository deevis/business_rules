class AddProcessedAtToFutureActions < ActiveRecord::Migration
  def change
    add_column :rules_future_actions, :processed_at, :datetime
  end
end