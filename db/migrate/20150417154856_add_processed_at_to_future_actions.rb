class AddProcessedAtToFutureActions < ActiveRecord::Migration
  def change
    add_column :pyr_future_actions, :processed_at, :datetime
  end
end