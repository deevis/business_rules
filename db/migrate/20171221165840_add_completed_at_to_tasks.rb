class AddCompletedAtToTasks < ActiveRecord::Migration
  def change
    add_column :rules_tasks, :completed_at, :datetime
  end
end
