class RulesEventAnalytics < ActiveRecord::Migration
  def change
  	create_table :rules_event_analytics do |t|
  		t.string :event_name
  		t.integer :count, default: 0
  		t.datetime :since								# 'since' is how long it has been since count was reset to 0
  		t.timestamps										# 'last_updated_at' says when count was last updated
  	end
  end
end
