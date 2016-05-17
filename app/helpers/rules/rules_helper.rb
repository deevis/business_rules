module Rules::RulesHelper

  # Don't drill into these types
  @@dont_drill_types = [:boolean, :datetime, :integer, :messaging_user, :string, :text]
  
  def drillable_rule_type?(check_type)
    !@@dont_drill_types.index(check_type)
  end

  # def get_rules_redirect
  #   if @actions_queue.present? && @actions_queue.first.present?
  #     redirect_url = @actions_queue.first[:redirect_url]
  #     if redirect_url.present?
  #       @actions_queue.shift 
  #     end
  #   end
  #   Rails.logger.info("Got WebActions redirect_url[#{redirect_url}]") if redirect_url.present?
  #   redirect_url
  # end

  # retrieve all actions to take on a single page response - that is, all up and until a redirect is hit
  def actions_queue
    if @actions_queue.nil?
      @actions_queue = Rules::WebActionsQueue.get(params, session)
      @actions_queue ||= []
      Rails.logger.info("Got actions_queue of length: #{@actions_queue.size}")
      Rails.logger.info("  =>  #{@actions_queue}") 
      # do the detect redirect part
      found_redirect = false
      leftovers = []
      @actions_queue.each{|c| leftovers << c if found_redirect;found_redirect ||= c[:redirect_url].present?}
      if leftovers.size > 0
        @actions_queue = @actions_queue - leftovers
        Rules::WebActionsQueue.store_queue(leftovers, params, session) 
        Rules::WebActionsQueue.set(@actions_queue)
      end
    end
    @actions_queue
  end



end
