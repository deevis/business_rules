# This migration comes from rules_engine (originally 20150417154856)
class AddProcessedAtToFutureActions < ActiveRecord::Migration[5.0]
  def change
    add_column :rules_future_actions, :processed_at, :datetime
  end
end