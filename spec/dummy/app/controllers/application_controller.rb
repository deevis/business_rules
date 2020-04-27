class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception


  around_action :rules_user

  private
    def rules_user
      Thread.current[:rules_user] = current_user
      yield
    ensure
      Thread.current[:rules_user] = nil
    end
end
