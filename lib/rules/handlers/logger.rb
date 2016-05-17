module Rules
  module Handlers
    class Logger < Rules::Handlers::Base

      needs :message, :string 
      needs :level, :select, optional: true, default: "info", values: ["debug", "info", "warn", "error"]

      def _handle 
        Rails.logger.send(level.to_sym, message)
      end

    end
  end
end