# This migration comes from rules_engine (originally 20140924154856)
class RulesEventAnalytics < ActiveRecord::Migration[5.0]
  def change
  	create_table :rules_event_analytics do |t|
  		t.string :event_name
  		t.integer :count, default: 0
  		t.datetime :since								# 'since' is how long it has been since count was reset to 0
  		t.timestamps										# 'last_updated_at' says when count was last updated
  	end
  end
end
