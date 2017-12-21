class CreateNotificationsAndTasks < ActiveRecord::Migration
  def change
    create_table :rules_notifications do |t|
      t.integer :user_id
      t.integer :item_id
      t.string :item_type
      t.string :category
      t.string :sub_category
      t.string :actionable_url
      t.string :message
      t.datetime :seen
      t.datetime :dismissed
      t.integer :priority

      t.timestamps null: false
    end

    create_table :rules_tasks do |t|
      t.integer :user_id
      t.string :title
      t.string :description
      t.integer :item_id
      t.string :item_type
      t.date :due_date
      t.integer :priority
      t.string :actionable_url

      t.timestamps null: false
    end
  end

end
