module Rules
  class NotificationsController < ApplicationController

    def index
      @notifications = current_user.notifications

      if params[:filter].present?
        if params[:filter_type] == "type"
          @notifications = @notifications.where(item_type: params[:filter])
        elsif params[:filter_type] == "predefined" && params[:filter] == "dismissed"
          @notifications = Rules::Notification.unscoped
                  .where("dismissed is not null and user_id = ?", current_user.id)
        elsif params[:filter_type] == "predefined" && params[:filter] == "business"
          @notifications = @notifications.non_messages
        end
      end

      @type_filters = @notifications.select("item_type as type, count(*) as cnt")
                                                .where("item_type is not null")
                                                .group("item_type")
                                                .order("cnt DESC")

      @notifications = @notifications.priority(params[:priority]) if params[:priority]
      @notifications = @notifications.page(params[:page]).per(30)

      respond_to do |format|
        format.html
        format.js # stream.js.erb
        format.json { render status: 200 }
      end
    end

    def stream
      @notifications = current_user.notifications.non_messages.limit(10)
      @messages = current_user.notifications.messages.limit(10)
      if params[:after]
        @notifications = @notifications.where("rules_notifications.id > ?", params[:after].to_i)
        @messages = @messages.where("rules_notifications.id > ?", params[:after].to_i)
      elsif params[:before]
        @notifications = @notifications.where("rules_notifications.id < ?", params[:before].to_i)
        @messages = @messages.where("rules_notifications.id < ?", params[:before].to_i)
      end

      respond_to do |format|
        format.js # stream.js.erb
        format.json { render json: { notifications: @notifications, messages: @messages } }
      end
    end

    def show
    end

    def mark_all_seen
      @notifications = current_user.notifications.where(seen: nil)
      @notifications.find_each { |n| n.mark_seen }
      redirect_to rules_notifications_path
    end

    def toggle_dismissed
      @notification = Rules::Notification.unscoped.where(user_id: current_user.id, id:params[:id]).first
      if @notification
        if @notification.dismissed
          @notification.dismissed = nil
        else
          @notification.dismissed = Time.now
        end
        @notification.save!
      end
      respond_to do |format|
        format.js
        format.json { render status: 200 }
      end
    end

    # takes an array of ids
    def mark_seen
      ids = params[:ids]
      if ids.present?
        @notifications = current_user.notifications.find(ids)
        @notifications.each do |n|
          n.mark_seen
        end
      end
      respond_to do |format|
        format.js
        format.json { render status: 200 }
      end
    end
  end
end
