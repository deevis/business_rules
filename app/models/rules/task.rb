# == Schema Information
#
# Table name: tasks
#
#  id             :integer          not null, primary key
#  user_id        :integer
#  title          :string(255)
#  description    :string(255)
#  item_id        :integer
#  item_type      :string(255)
#  due_date       :date
#  priority       :integer
#  actionable_url :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
module Rules
  class Task < ActiveRecord::Base
    belongs_to :user 
    belongs_to :item, polymorphic: true
  end
end