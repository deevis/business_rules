# This migration comes from rules_engine (originally 20140925154856)
class CreateRulesActionAnalytics < ActiveRecord::Migration[5.0]
  def change
  	create_table :rules_action_analytics do |t|
  		t.string :action_name
  		t.integer :count, default: 0
  		t.datetime :since								# 'since' is how long it has been since count was reset to 0
  		t.timestamps										# 'last_updated_at' says when count was last updated
  	end
  end
end