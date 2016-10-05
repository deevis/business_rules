# == Schema Information
#
# Table name: rules_unique_rule_firings
#
#  id                :integer          not null, primary key
#  rule_id           :string
#  unique_expression :string
#  fired_at          :datetime
#

class Rules::UniqueRuleFiring < ActiveRecord::Base

end
