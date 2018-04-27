# == Schema Information
#
# Table name: rules_tasks
#
#  id             :integer          not null, primary key
#  user_id        :integer
#  title          :string(255)
#  description    :string(255)
#  item_id        :integer
#  item_type      :string(255)
#  due_date       :date
#  priority       :integer
#  actionable_url :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  completed_at   :datetime
#

module Rules
  class Task < ActiveRecord::Base
    belongs_to :user 
    belongs_to :item, polymorphic: true

    scope :due_today, -> () {
      where({ due_date: Date.current, completed_at: nil })
    }

    scope :overdue, -> () {
      where({ completed_at: nil }).where('due_date < ?', Date.current)
    }

    scope :future, -> () {
      where({ completed_at: nil }).where('due_date > ?', Date.current)
    }

    scope :no_due_date, -> () { where({ due_date: nil, completed_at: nil }) }

    scope :completed, -> () { where.not({ completed_at: nil }) }

    scope :open, -> () { where({ completed_at: nil }) }

    # TODO: is this being used? (:calendar_tasks)
    scope :calendar, -> () {
      self.where("due_date is null or (due_date <= ? and due_date >= ?)",
                 Date.current + 7,
                 Date.current - 7)
          .order(:completed_at)
    }    

    def priority_text
      if priority.nil?
        'no_priority'
      else
        self.priority
      end
    end

    def completed?
      completed_at.present?
    end

    def days_to_complete
      (Date.current.to_date - due_date.to_date).to_i rescue nil
    end

    def self.task_type
      cms_options_map :task_type
    end

    def self.status_list
      cms_options_map :status
    end

    def self.priority_list
      cms_enum_options_map :priority
    end

    def system_assigned?
      source == "system"
    end

    # TODO: is this right?
    def as_json(options = {})
      {
        id:                 self.id,
        title:              self.title,
        description:        self.description || "",
        start:    (self.due_date.strftime('%Y-%m-%dT%H:%M:00%z') rescue ""),
        :"end" => (self.due_date.strftime('%Y-%m-%dT%H:%M:00%z') rescue ""),
        allDay:             true,
        className:          "task",
        recurring:          false,
        resource:           self.user_id || "",
        resourceId:         self.user_id || "",
        url: Rails.application.routes.url_helpers.rules_task_path(self),
        color:              "#FFEBCC",
        textColor:          "#000",
        calendar_item_type: "task",
        priority:           self.priority,
        completed_at:       self.completed_at
      }
    end

    # TODO: is this being used?
    def self.view_tasks_by_type user, options
      type = options.split
      if type.first == "sort"
        column_name = type.last
        tasks_due_today  = user.user_tasks.due_today.order("#{column_name} ASC")
        tasks_overdue    = user.user_tasks.overdue.order("#{column_name} ASC")
        future_tasks     = user.user_tasks.future.order("#{column_name} ASC")
        no_due_date      = user.user_tasks.no_due_date.order("#{column_name} ASC")
        completed_tasks  = user.user_tasks.completed.order("#{column_name} ASC")
        incomplete_tasks = user.user_tasks.open.order("#{column_name} ASC")
        completed_incomplete_tasks = completed_tasks + incomplete_tasks
      end

      return [tasks_due_today,
              tasks_overdue,
              future_tasks,
              incomplete_tasks,
              no_due_date,
              completed_incomplete_tasks,
              completed_tasks]
    end

  end
end
