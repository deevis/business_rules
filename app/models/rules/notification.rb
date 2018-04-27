# == Schema Information
#
# Table name: rules_notifications
#
#  id             :integer          not null, primary key
#  user_id        :integer
#  item_id        :integer
#  item_type      :string(255)
#  category       :string(255)
#  sub_category   :string(255)
#  actionable_url :string(255)
#  message        :string(255)
#  seen           :datetime
#  dismissed      :datetime
#  priority       :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
module Rules
  class Notification < ActiveRecord::Base
    belongs_to :user 
    belongs_to :item, polymorphic: true

    default_scope -> {where(dismissed: nil)}

    def mark_seen
      unless self.seen
        self.seen ||= Time.now
        self.save
      end
    end

    def seen?
      !!self.seen.present?
    end

    def dismissed?
      !!self.dismissed.present?
    end
    
    def self.priority_map
      {
        "10" => :low,
        "30" => :medium,
        "50" => :high,
        "70" => :urgent,
        "90" => :critical,
      }
    end

    def broadcast_external
      # TODO: determine mechanism by which to externally alert a user of their notification
    end

  end
end