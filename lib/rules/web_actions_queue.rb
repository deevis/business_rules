module Rules
  module WebActionsQueue

    def self.get(params = nil, session = nil)
      q = Thread.current[:rules_web_actions_queue]
      return q unless q.nil?
      if q.nil? && session.present? && session[:rule_actions_queue_leftovers_id].present?
        Rails.logger.info("Got actions_queue of length: #{q.size}") if q.present?
        if (params.blank? || params[:additional_rules_moved].blank?)
          id = session.delete(:rule_actions_queue_leftovers_id)
          Rails.logger.info("  - loading stored WebActionsQueue from redis-session[#{id}]")
          q = Rails.cache.read(["rule_actions_queue_leftovers", id])
          Rails.logger.info("  - got actions_queue of length: #{q.size}") if q.present?
        end
      end
      q ||= []
      Thread.current[:rules_web_actions_queue] = q
    end

    def self.set(queue)
      Thread.current[:rules_web_actions_queue] = queue
    end

    def self.clear
      Rails.logger.info("  Clearing Thread.current[:rules_web_actions_queue]")
      Thread.current[:rules_web_actions_queue] = nil
    end

    def self.add(handler, config = {})
      _setup(handler, config)
      Rails.logger.info("  Thread.current[:rules_web_actions_queue].add: #{config}")
      r = Rules::WebActionsQueue.get << config
      _log_and_return(r)
    end

    def self.insert(handler, insert_position = 0, config = {})
      _setup(handler, config)
      Rails.logger.info("  Thread.current[:rules_web_actions_queue].insert: #{config}")
      r = Rules::WebActionsQueue.get.insert(insert_position, config) 
      _log_and_return(r)
    end

    # Store whatever is left on the queue in redis-session space and clear the queue
    def self.store_queue(queue = nil, params, session)
      queue ||= Rules::WebActionsQueue.get(params, session)
      if queue.present?
        # Store the rest away to be processed the next request
        id = SecureRandom.hex(8)
        Rails.logger.info("Storing web_actions_queue id[#{id}] for future requests : #{queue.map{|a| a[:action_type]} }" )
        Rails.cache.write(["rule_actions_queue_leftovers", id], queue, expires_in: 30.minutes)
        session[:rule_actions_queue_leftovers_id] = id
        params[:additional_rules_moved] = "true"
      end
    ensure
      Rules::WebActionsQueue.clear
    end    

    def self._log_and_return(rules_queue) 
      Rails.logger.info("   Thread.current[:rules_web_actions_queue].size = #{Thread.current[:rules_web_actions_queue].size rescue 0}")
      rules_queue
    end

    def self._setup(handler, config = {})
      config[:rule_id] = handler.action.rule.id.to_s rescue "NO_RULE_ID"
      config[:action_id] = handler.action.id.to_s
      config[:action_type] = handler.class.name
    end
          
  end
end