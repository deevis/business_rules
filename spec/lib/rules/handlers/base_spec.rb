puts "...models/rules/rule_spec.rb"
require 'spec_helper'
require 'rules/handlers/base'

describe Rules::Handlers::Base do

	pending "it can evaluate needs from rule context"

	it "it can evaluate templates from rule context" do
		a = Rules::Action.new(template: {"test_template" => "This is a test template"})
		base = Rules::Handlers::Base.new(a, {})
		result = base.eval_template(:test_template)
		result.should eq "This is a test template"
	end

	it "it can evaluate interpolated templates from rule context" do
		a = Rules::Action.new(template: {"test_template" => "This is an {value} template"})
		base = Rules::Handlers::Base.new(a, {}, Rules::RuleContext.new(value: "interpolated"))
		result = base.eval_template(:test_template)
		result.should eq "This is an interpolated template"
	end

	it "it can evaluate code snippets within interpolated fields with '.' in them" do
		a = Rules::Action.new(template: {"test_template" => "This is a {[1,2,3].join(',')} template"})
		base = Rules::Handlers::Base.new(a, {}, Rules::RuleContext.new({}))
		result = base.eval_template(:test_template)
		result.should eq "This is a 1,2,3 template"
	end

	it "it can evaluate code snippets within interpolated fields without '.' in it" do
		a = Rules::Action.new(template: {"test_template" => "This is a {[1,2,3]} template"})
		base = Rules::Handlers::Base.new(a, {}, Rules::RuleContext.new({}))
		result = base.eval_template(:test_template)
		result.should eq "This is a [1, 2, 3] template"
	end

	it "it WILL NOT WORK for interpolated fields with nested curly braces in them" do
		a = Rules::Action.new(template: {"test_template" => "This is a { [1,2,3].map{|x| x+1} } template"})
		base = Rules::Handlers::Base.new(a, {}, Rules::RuleContext.new({}))
		result = base.eval_template(:test_template)
		# This is checking that it WILL NOT WORK - it doesn't raise an exception, but we cannot get the correct value this way
		result.should eq "This is a { [1,2,3].map{|x| x+1} } template"
	end

	# it "it will for interpolated fields with lambda mappings" do
	# 	a = Rules::Action.new(template: {"test_template" => "This is a {expression} template"})
	# 	base = Rules::Handlers::Base.new(a, {expression:" ->{[1,2,3].map{|x| x+1}}"}, Rules::RuleContext.new({}))
	# 	result = base.eval_template(:test_template)
	# 	result.should eq "This is a [2, 3, 4] template"
	# end


	it "multiple evaluations of interpolated templates from rule context will not pollute the result with #'s" do
		a = Rules::Action.new(template: {"test_template" => "This is an {value} template"})
		base = Rules::Handlers::Base.new(a, {}, Rules::RuleContext.new(value: "interpolated"))
		result = base.eval_template(:test_template)
		result.should eq "This is an interpolated template"

		result = base.eval_template(:test_template)
		result.should eq "This is an interpolated template"

		result = base.eval_template(:test_template)
		result.should eq "This is an interpolated template"
	end


end
