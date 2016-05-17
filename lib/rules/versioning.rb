module Rules
  module Versioning

    def self.included(base)
      base.send :include, Mongoid::Timestamps::Short # For c_at and u_at.
      base.send :include, Mongoid::Versioning

      base.before_save :set_updated_by
      
      base.max_versions 25 
    
      base.field :updated_by, type: String
      base.field :updated_action, type: String
      base.field :was_valid, type: Boolean
    end

    private
      def set_updated_by
        if Thread.current[:user]
          self.updated_by = Thread.current[:user].try(:username)
        end
        self.actions_hashed = self.actions.to_json
        self.was_valid = self.ready?
        #puts "Set valid = #{self.valid}"
        true
      end

  end
end