# This file is copied to spec/ when you run 'rails generate rspec:install'
puts "...spec_helper.rb"
# simplecov needs to come before the rest of application files are required so it can track them
if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start "rails" 
end

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../spec/dummy/config/environment", __FILE__)

require "rspec/rails"
require "rspec/autorun"

require "mongoid"
require "mongoid/versioning"

# Model classes A,B,C for use in chaining Rules
module Rules
  module Test
    @@next_id = 0
    def self.get_id
      @@next_id += 1
    end

    @@instance_registry ||= Hash.new{|hash, key| hash[key] = [];}
    def self.instance_registry(reload = false)
      if reload || @@instance_registry == nil 
        puts "\nSETTING INSTANCE REGISTRY = Hash.new([])\n"
        @@instance_registry = Hash.new{|hash, key| hash[key] = [];}
      end
      #puts "Returning @@instance_registry"
      @@instance_registry
    end

    def self.reset_instance_registry
      instance_registry(true)
    end

    class ActiveDummy
      include Rules::ContextFields
      attr_accessor :id 
      

      attr_accessor :from_event_1
      expose_rules_field :from_event_1, :string
      attr_accessor :from_event_2
      expose_rules_field :from_event_2, :string

      def attributes; {id: id}; end
      def changes;{};end
      def self.after_save(x);end
      def self.after_create(x);;end
      def self.before_destroy(x);end
      def self.find(id)
        found = Rules::Test.instance_registry[self].detect{|i| i.id.to_s == id.to_s}
        puts "Found existing instance of #{self} with id = #{found.id}" if found
        found 
      end
      def save 
        if self.id.blank?
          self.id = Rules::Test.get_id
          puts " --- save: setting id for #{self.class} instance = #{self.id}"
          Rules::Test.instance_registry[self.class] << self
          puts " --- CREATED(1) #{self.class.name}[#{self.id}]"
          puts "     Registry: #{Rules::Test.instance_registry}"
          puts "       Calling raise_created"
          self.send :raise_created
        else
          puts "       Calling raise_updated"
          self.send :raise_updated
        end
      end
      def save!; save();end
      def self.create(params = {})
        puts "Creating instance of #{self}"
        i = self.new
        i.id = Rules::Test.get_id
        Rules::Test.instance_registry[i.class] << i
        puts " --- CREATED(2) #{i.class.name}[#{i.id}]"
        puts "     Registry: #{Rules::Test.instance_registry}"
        puts "       Calling raise_created"
        i.send :raise_created # cuz private
        i
      end

      def initialize
      end

      include Rules::ModelEventEmitter unless ancestors.index(Rules::ModelEventEmitter)
    end

    class A < ActiveDummy;end 
    class B <  ActiveDummy;end 
    class C <  ActiveDummy;end 
    class D <  ActiveDummy;end 
    class E <  ActiveDummy;end 
    class F <  ActiveDummy;end 
    class G <  ActiveDummy;end 
    class H <  ActiveDummy;end 
  end
end

class User < Rules::Test::ActiveDummy

  def email
    "some@email.com"
  end
end


# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

Rules::EventConfigLoader.reload_events_dictionary

Rules.event_processing_strategy = :synchronous
Rules.logging_level = :info 
Rules.disallow_web_redirects_from = 'sign_out|heartbeat'
Rules.rule_activity_channel_enabled = false
Rules.activate_event_processing


RSpec.configure do |config|
  config.before(:each) do
    [:mongoid, :active_record].each do |s|
      DatabaseCleaner[s].clean_with(:truncation)
      DatabaseCleaner[s].clean
    end
    Rules::WebActionsQueue.clear
  end

  config.before(:each) do
    DatabaseCleaner[:active_record].strategy = :transaction
  end

  config.before(:each) do
    # We were starting cleaner for mongoid too. But we decided not to do it anymore
    [:active_record, :mongoid].each do |s|
      DatabaseCleaner[s].start
    end
  end

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  # config.order = "random"


end
