module Rules
	module EventConcerns

		def self.included(base)
			_register(base)
		end

		def self._register(klazz)
			self.registered_classes ||= []
			self.registered_classes << klazz if !self.registered_classes.index(klazz)
		end

		def build_event_payload(event_type, class_name, action, extras={})
				payload = { type: event_type, klazz: self.class.name, action: action, id: self.id, data: self, 
							user: Thread.current[:user] }.merge(extras)
				ActiveSupport::Notifications.instrument("Rules_#{event_type}", payload )

		end

	end
end