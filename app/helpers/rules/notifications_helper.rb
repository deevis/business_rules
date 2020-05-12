module Rules::NotificationsHelper

  def item_display_name(item)
    if item.respond_to?(:display_name)
      item.display_name
    else
      "#{item.class.to_s.demodulize}[#{item.id}]"
    end
  end

  def item_path(item)
    polymorphic_path(item)
  end
end