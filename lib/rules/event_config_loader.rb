require 'action_dispatch/routing/inspector'
module Rules
  class EventConfigLoader
    @@events_dictionary ||= nil
    
    SYSTEM_EVENTS = ["TimerEvent", "DynamicEvent"]
    CONTROLLER_CONTEXT = {"system" => :messaging_user, "actor" => :user, "user_agent" => :string, 
            "referrer" => :string, "original_url" => :string, "referrer" => :string, 
            "remote_ip" => :string, "xhr" => :boolean, "data" => :hash, "klazz" => :string, 
            "action" => :string }

    def self.reload_events_dictionary
      puts "Reloading EventsDictionary"
      @@events_dictionary = nil
      events_list(true)
    end

    # A simple list containing every Event known to the system...
    def self.events_list(refresh = false)
      puts "DEBUG[events_list]"
      Rules::EventConfigLoader.events_dictionary(refresh).map do |et,et_v| 
        et_v.map do |k,v| 
          if v[:actions].present?
            v[:actions].map do |a| 
              "#{k}::#{a}"
            end
          else 
            k
          end
        end
      end.flatten
    end


    def self.events_dictionary(refresh = false)
      return @@events_dictionary if @@events_dictionary && !refresh
      # Force load of models and controllers when eager class loading isn't enabled by default
      # http://stackoverflow.com/questions/516579/is-there-a-way-to-get-a-collection-of-all-the-models-in-your-rails-app      
      puts "DEBUG[business_rules] Building Events Dictionary"
      start_time = Time.new
      if Rules.active_record
        puts "Rules - Adding ModelEventEmitter to ActiveRecord::Base"
        ActiveRecord::Base.send :include, Rules::ModelEventEmitter
        model_classes = ActiveRecord::Base.connection.tables.map do |t|
          begin
            t.classify.constantize
          rescue Exception => e
            Rails.logger.warn "Couldn't constantize: #{t.classify} : #{e.message}"
            nil
          end
        end.compact
        model_classes.each do |mc| 
          puts "Rules::EventConfigLoader loading #{mc.to_s}" 
          mc.class_eval {}
        end
      end
      
      if Rails.env.development? 
          Rules.development_model_paths.each do |path|
          puts "Rules::EventConfigLoader - scanning models via #{path}"
          Dir.glob(path).sort.each do |entry|
            puts "   -  Loading model: #{entry}"
            require_dependency "#{entry}"
          end
        end
      end

      puts "\n\nRules::ModelEventEmitter.registered_classes = #{Rules::ModelEventEmitter.registered_classes}\n\n"
      controller_events = add_controller_events
      controller_events["ApplicationController"] = {actions: ["*"], context:CONTROLLER_CONTEXT}
      @@events_dictionary = {
        application_events: add_application_events,
        model_events: add_model_events({},Rules::ModelEventEmitter.registered_classes),
        controller_events: controller_events,
        system_events: add_system_events
      }
      puts "DEBUG[business_rules] Events Dictionary Built in #{Time.new - start_time} seconds\n\n" 
      @@events_dictionary
    end


    def self.add_application_events
      h = {}
      Rules::Events::ApplicationEventBase.subclasses.each do |sc| 
        event_name = sc.name
        cfg = { "system" => :messaging_user,
         #       "actor" => :user, 
                "klazz" => :string
        }
        cfg["trigger"] = sc.trigger_class.name.underscore if sc.trigger_class.present?
        h[event_name] = { context: cfg, actions: ["raised"] }
      end
      h
    end


    def self.add_system_events 
      h = {}
      h["TimerEvent"] = {"actions" => ["tick"], "context" =>  { "trigger" => "inferred"}}
      h["DynamicEvent"] = {"actions" => ["*"], "context" => { "trigger" => "data"}}
      h
    end

    def self.add_controller_events
      results = {}
      if Rails.application.routes.routes.to_a.blank?
        Rails.application.reload_routes!
      end
      r=Rails.application.routes.routes.to_a.dup
      if r.blank? 
        Rails.logger.error("\n\n\n\nWe don't have any Rails Routes to build ControllerEvents from!\n\n\n\n")
      end
      i=ActionDispatch::Routing::RoutesInspector.new r
      m=i.send(:collect_routes,r)
      events = m.map do |a| 
        p=a[:reqs].split("#")
        class_name = "#{p[0].camelcase}Controller"
        c = (results[class_name] ||= {context: CONTROLLER_CONTEXT, actions:[]})
        if p[1]
          action = p[1].split(" ").first    # it might have extra routing info on the end (subdomain, format, etc...) - we don't use this yet
          c[:actions] << action unless c[:actions].include? action
        end
      end
      results
    end

    # One liner to dump the rules config in consoles
    # Rules::RulesConfig.events.each{|k,v| puts k.to_s.titleize; v.keys.sort.eac:qh{|key| puts "   #{key}"; v[key][:context].each{|col_name, col_config| puts "      #{col_name}(#{col_config[:type]})"}}};nil
    private
      def self.add_model_events(results={}, event_classes)
        puts "DEBUG[business_rules] add_model_events" 
        event_classes.each do |klazz|
          puts "DEBUG[business_rules] #{klazz}" 
          cols={};
          if klazz != ActiveRecord::Base && klazz != ActiveRecord::SchemaMigration  # Don't add ActiveRecord::Base as an event type, but recurse its subclasses later
            cols["system"] = :messaging_user
            cols["actor"] = :user
            cols["klazz"] = :string
            cols["trigger"] = klazz.name.demodulize.downcase.to_sym
            results[klazz.name] = {context: cols, actions: ModelEventEmitter.model_actions }
          end
          klazz.subclasses.each do |sc| 
            add_model_events(results, [sc])
          end
          puts "DEBUG[business_rules] #{klazz} :: #{results[klazz.name]}" 
        end
        results
      end
  end    
end
