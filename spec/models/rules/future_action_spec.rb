# == Schema Information
#
# Table name: rules_future_actions
#
#  id                   :integer          not null, primary key
#  run_at               :datetime
#  contingent_script    :string
#  run_at_expression    :string
#  unique_expression    :string
#  recurring_expression :string
#  rule_id              :string
#  action_id            :string
#  action_handler       :string
#  context_mapping      :string(2000)
#  template             :string(6000)
#  event                :text
#  created_at           :datetime
#  updated_at           :datetime
#  priority             :integer          default(0)
#  unique_id            :string
#  processed_at         :datetime
#

require 'spec_helper'

describe Rules::FutureAction do
  pending "add some examples to (or delete) #{__FILE__}"
end
