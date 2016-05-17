module Rules
	module ContextFields
    extend ActiveSupport::Concern

		mattr_accessor :rules_fields
		@@rules_fields = {}       #  { User.class => { :display_name => { :type => :string }}}
		
		def self.for_class(klazz)
			rules_fields[klazz] || {}
		end

		module ClassMethods
			def expose_rules_field(name, type = :string)
				class_fields = (Rules::ContextFields.rules_fields[self] ||= {})
				class_fields[name] = {type: type}
			end			
		end

	end
end