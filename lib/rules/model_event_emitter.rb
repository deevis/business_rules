# This will hook into ActiveRecordCallbacks and raise the appropriate crud events
#
# For reference: 
# 					http://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html
#
# For sanity:
# 				(-) save
# 				(-) valid
# 				(1) before_validation
# 				(-) validate
# 				(2) after_validation
# 				(3) before_save
# 				(4) before_create
# 				(-) create
# 				(5) after_create
# 				(6) after_save
# 				(7) after_commit  -or-  after_rollback
# 				
#               (1) before_destroy
# 				(-) destroy
# 				(2) after_destroy
#
# 				(-) find
# 				(1) after_find
# 				(2) after_initialize

module Rules
	module ModelEventEmitter

		@@registered_classes = []

		def self.included(base)
			#base.send :extend, ClassMethods
			#unless ( File.basename($0) == "rake" && ARGV.include?("db:migrate") )
			#end
			if base.ancestors.include?(ActiveRecord::Base)
				Rails.logger.info "Registering buffered ModelEventEmitter[#{base}]"
				base.after_update :buffer_updated
				base.after_create :buffer_created
				# this used to be 'before_destroy' - why?  i dunno...
				base.after_destroy :buffer_destroyed
				
				base.after_commit(:_flush_events) 
				base.attr_accessor :_buffered_events
			else
				Rails.logger.info "Registering un-buffered ModelEventEmitter[#{base}]"
				base.after_update_commit(:raise_updated) 
				base.after_create_commit(:raise_created) 
				base.after_destroy_commit(:raise_destroyed) 
			end

			@@registered_classes << base if !registered_classes.index(base)
		end


		def self.registered_classes
			@@registered_classes
		end

		def self.model_actions
 			[:create, :update, :delete]
		end

		private
			# An updated event is different from the rest.  It also has a key :changes like:
			# 
			# event[:changes] = {
			# 									"description"=>["old", "new"], 
			# 									"title"=>["before", "after"], 
			# 									"updated_at"=> [Thu, 20 Mar 2014 14:02:41 MDT -06:00, Thu, 20 Mar 2014 14:04:05 MDT -06:00]
			# 									}
			#
			# This has all the changed fields as keys, and the values for each is an array [before,after]
			# There will ALWAYS be an "updated_at" value that shows the time the before and 
			#       after values were (previously) set
			#
			def raise_updated(buffered: false)
				# Only raise updated if changes are actually present
				filtered_changes = Rules.data_filter.filter changes if changes.present?
				_notify("update", buffered: buffered, changes: filtered_changes) if filtered_changes.present?
			end

			def raise_created(buffered: false)
				_notify("create", buffered: buffered)
			end

			def raise_destroyed(buffered: false)
				_notify("delete", buffered: buffered)
			end

			def buffer_updated
				raise_updated(buffered: true)
			end

			def buffer_created
				raise_created(buffered: true)
			end

			def buffer_destroyed
				raise_destroyed(buffered: true)
			end

			# takes all events encountered during our commit and flushes them all out
			def _flush_events
				return if self._buffered_events.blank?
				while ((event_hash = self._buffered_events.shift) != nil) do 
					Rules::RulesEngine.raise_event(event_hash)
				end
			end

			def _notify(action, buffered: , changes: {})
				begin
					return if Rules.disabled? || self.class.name == "ActiveRecord::SchemaMigration"
					Rails.logger.debug "ModelEventEmitter   action[#{action}]   class[#{self.class.name}]  changes: #{changes}"
					event_hash = build_event_hash( "ModelEvent", self.class.name, action, changes)
					event_hash[:id] = self.id 
					if buffered
						(self._buffered_events ||= []) << event_hash
					else
						Rules::RulesEngine.raise_event(event_hash)
					end
				rescue => e
					Rails.logger.error "Unable to raise event for #{self} : #{e.message}"
				end
			end

			def build_event_hash(event_type, class_name, action, changes = {})
					event_hash = { processing_stack: Rules::Rule.processing_stack, type: event_type, 
													klazz: self.class.name, action: action, id: self.id, data: self, 
													user: Rules.current_user.call }
					event_hash[:changes] = changes if changes.present?
					Rules.event_extensions.(event_hash)
			end

	end
end
