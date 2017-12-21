require 'redis-rails'

class RulesRunnerPool
  @@thread_count = 0              # The current number of threads in the pool
  @@jobs_run = 0                  # The total number of jobs that has been run

  cattr_accessor :pool_size
  @@pool_size = 40                # The max size of the pool - determines how many threads can run at a time
  
  @@semaphore = Mutex.new

  # RulesRunnerPool.config do |c|
  #   c.pool_size = 2
  # end
  def self.config(&block)
    yield(self)    
  end

  def self.stats 
    { active_threads: @@thread_count, max_threads: @@pool_size, jobs_run: @@jobs_run }
  end

  def self.run(payload, &block)
    begin
      @@semaphore.synchronize do 
        raise "dammit" if @@thread_count >= @@pool_size 
        @@jobs_run += 1
        @@thread_count += 1
      end
    rescue Exception => e 
      sleep(0.01)
      retry if e.message == "dammit"
    end
    #puts "\nRunner #{@@jobs_run} [#{@@thread_count}]\n"
    Thread.new do 
      begin
        block.call(payload)
      rescue Exception => e 
        puts e.message
        puts e.backtrace
      ensure
        ActiveRecord::Base.connection.close
        @@semaphore.synchronize do 
          @@thread_count -= 1
        end
      end
    end
  end
end


namespace :rules do
  desc "Disable rules processing for rake task"
  task :disable do 
    Rules.disable!
  end
  namespace :redis do
    desc "Process events loop"
    task :processor => :environment do
      RulesRunnerPool.config do |c|
        # Change this value to match the size of the DB pool
        c.pool_size = APP_CONFIG[:database_pool_size]
      end
      raise "Redis processor doesn't handle strategy [#{Rules.event_processing_strategy}]" unless Rules.event_processing_strategy == :redis
      puts "\n\nEvents Processor connecting to #{Rules.redis_host}:#{Rules.redis_port}/#{Rules.redis_queue_name}\n\n"
      runner_id = "runner_#{SecureRandom.hex(4)}"
      start_time = Time.now
      processing_queue = Redis.new   # Events come in on this queue via brpop
      analytics_queue = Redis.new    # We perform introspection upon the queue with this connection
      last_private_pub = (Time.now - 10)
      puts "...listening..."
      while true do
        puts "#{runner_id}: #{Time.now} Waiting for events.  Queue Size: #{analytics_queue.llen(Rules.redis_queue_name)} #{RulesRunnerPool.stats}"
        STDOUT.flush
        msg = processing_queue.brpop(Rules.redis_queue_name, timeout: 10) 
        if msg && msg[1].present?  # If we timed-out then this will be nil - only process if present
          RulesRunnerPool.run(msg[1]) do |payload|
            data = JSON.parse(payload).with_indifferent_access
            puts "#{data}"
            Rules::RulesEngine.handle_event data, :asynchronous, processor_id: runner_id   
          end
        end
        if Rules.rule_activity_channel_enabled && Rules.rule_activity_channel.present? && (Time.now - last_private_pub > 5)
          queue_size = analytics_queue.llen(Rules.redis_queue_name)
          Rules::Rule.publish_if_enabled RulesRunnerPool.stats.merge( {type:"runner", id: runner_id, start_time: start_time, queue_size: queue_size } )
          last_private_pub = Time.now
        end

        # TODO: DBH - we need to reconnect our queues if they get disconnected by a Redis server restart

      end

    end
  end
end

#####################################################################################
#
# Some Test Scenarios
# 
#####################################################################################
#
# Scenario 1 - PubSub Channels
#

# # Emitter - Run this in one rails console
# s=Time.now;1000.times{|x| redis.pub("q#{x%5}", x)};puts Time.now.to_f - s.to_f

# # Processor - Run this in a different rails console
#   
# redis.subscribe(['q0', 'q1', 'q2', 'q3', 'q4']) do |on|
#   on.subscribe do |channel, subscriptions|
#     puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
#   end

#   on.message do |channel, msg|
#     RulesRunnerPool.run(msg) do |payload|          
#       sleep(0.25)
#       puts "[#{channel}] #{Time.now.to_f} - #{payload}"
#     end
#   end
# end
     

#####################################################################################
#
# Scenario 2 - PushPop  ( lpush, brpop specifically )
#

# Emitter - Run this in one rails console
# s=Time.now;1000.times{|x| redis.lpush("q0", x)};puts Time.now.to_f - s.to_f

# # Processor - Run this in a different rails console
# redis = Redis.new(host:"localhost", port:6379)
# while true do
#   msg = redis.brpop("q0")
#   RulesRunnerPool.run(msg[1]) do |payload|
#     sleep(0.25)
#     puts "#{Time.now.to_f} - #{payload}"
#   end
# end



# PubSub - 5 channels and 40 Threads (workload: puts and sleep(0.25) )
# ---------------------------------------------------------------------


# 1000 Events 
#   Published: 0.3 seconds
#   Consumed:  6.2 seconds

# 1000 Events 
#   Published: 0.3 seconds
#   Consumed:  6.3 seconds




# PushPop - 1 Queue and 40 Threads (workload: puts and sleep(0.25) )
# -------------------------------------------------------------------
# 1000 Events 
#   Published: 0.3 seconds
#   Consumed:  6.4 seconds

# 1000 Events 
#   Published: 0.3 seconds
#   Consumed:  6.3 seconds