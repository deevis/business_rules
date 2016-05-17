module Rules
  module Jobs
    class RunFutureActions
      @queue = :future_actions

      def self.perform    # Resque-scheduler want's #perform
        puts "Running FutureActions"
        Rules::FutureAction.run_next_batch
      end

    end
  end
end