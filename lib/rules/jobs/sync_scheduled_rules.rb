# Makes sure that all TimerEvent (Scheduled) rules have the necessary Schedules in place
#
#
# In your application's resque-scheduler.yml:
#
#   sync_scheduled_rules:
#     every: 4h
#     class: Rules::Jobs::SyncScheduledRules
#     args:
#     description: Ensure Schedules for TimerEvent-based Rules are in-place and correct
# 
module Rules
  module Jobs
    class SyncScheduledRules
      @queue = :scheduled_rules

      def self.perform    # Resque-scheduler wants #perform
        puts "Syncing ScheduledRules"
        
      end

    end
  end
end