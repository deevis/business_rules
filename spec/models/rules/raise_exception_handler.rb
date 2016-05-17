require 'rules/handlers/base'

class Rules::RaiseExceptionHandler < Rules::Handlers::Base

 
  def handle
    raise "You're Exception, sir..."
  end

end