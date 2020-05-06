module Rules::TasksHelper

  # where t is a Task
  def contextual_task_link(t)
    if t.actionable_url.present?
      if t.actionable_url.index("?")
        "#{t.actionable_url}&task_context_id=#{t.id}"
      else
        "#{t.actionable_url}?task_context_id=#{t.id}"
      end
    elsif t.item.present?
      polymorphic_path(t.item, task_context_id: t.id)
    else 
      nil
    end
  end
  
  def task_completed(t)
    if t.completed?
      "Completed at: #{t.completed_at}"
    else
      link_to "Mark Complete", toggle_completion_rules_task_path(t), remote: true, class: "btn btn-sm btn-info"
    end
  end
end
