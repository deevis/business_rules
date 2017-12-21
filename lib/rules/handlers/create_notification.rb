class Rules::Handlers::CreateNotification < Rules::Handlers::Base

  needs :recipient, :messaging_user

  needs :regarding, :object
  needs :priority, :integer_select, default: 30, min: 1, max: 100
  needs :sub_category, :string, optional: true
  needs :actionable_url, :string, optional: true

  template :message


  # implement for_recipient instead of handle since including MessagingUserEmitter
  def _handle
    user = recipient
    if user.class != User
      puts "Skipping notification for non-User class: #{recipient.class}"
    else
      message = eval_template(:message).presence
      # TODO: Check cuz we need either a message or a notification_item (once optional is implemented)
      notification = Rules::Notification.create!({
        user: user,
        category: @event[:klazz],
        sub_category: sub_category,
        item: regarding,
        actionable_url: actionable_url,
        message: message,
        priority: priority
      })
      notification.broadcast_external
    end
  end
end
