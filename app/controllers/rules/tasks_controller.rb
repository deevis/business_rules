module Rules
  class TasksController <  ApplicationController

    def index
      # Still need to perform the _index work for API access (mobile)
      params[:type] ||= 'incomplete'
      _index
      @type ||= params[:type]
      respond_to do |format|
        format.html
        format.json { render status: 200 }
        format.js  { render  json: @tasks }
      end
    end

    def priority
      respond_to do |format|
        format.json { render status: 200, json: Rules::Task.priorities }
      end
    end

    def calendar
      options = {}
      options[:start_time] = params['start'] if !params['start'].blank?
      options[:end_time] = params['end'] if !params['end'].blank?

      @tasks = current_user.tasks.where("due_date is not null")
      start_time = Time.at(params['start'].to_i).to_date rescue 30.days.ago.to_date
      end_time = Time.at(params['end'].to_i).to_date rescue 30.days.from_now.to_date

      @tasks.where("due_date >= ?", start_time.to_datetime.to_formatted_s(:db))
      @tasks.where("due_date <= ?", end_time.to_datetime.to_formatted_s(:db))
      @tasks.order(:due_date)

      respond_to do |format|
        format.html {render :index}
        format.json  { render :layout => false, :json => @tasks.to_json }
        format.js  { render :json => @tasks.to_json }
      end
    end

    def show
      @task = current_user.tasks.find(params[:id])
      respond_to do |format|
        format.html
        format.js
        format.json { render status: :ok }
      end
    end

    def new
      #@contact=current_user.contacts
      @task = Rules::Task.new()
      @task.actionable_item_id = params[:actionable_item_id]
      @task.actionable_item_type = params[:actionable_item_type]
      respond_to do |format|
        format.html
        format.js
      end
    end

    def create
      due_date = params[:rules_user_task].delete(:due_date)
      due_date = Time.zone.strptime(due_date, "%m/%d/%Y") if due_date.present?
      # TODO: refactor out these magic numbers.
      if params[:rules_user_task][:calendar_id] == "3"
        [1, 2].each do |t|
          @task = params[:rules_user_task].clone.merge!("calendar_id" => t)
          @task = Rules::Task.new(@task)
          @task.user_id = current_user.id
          @task.due_date = due_date
          @succ_task = @task.save
        end
      else
        @task = Rules::Task.new(user_tasks_params)
        @task.due_date = due_date
        @task.user_id = current_user.id
        @succ_task = @task.save
        if @task.actionable_item_id.present? and
           @task.actionable_item_type == "PyrCrm::Contact"
          @contact = PyrCrm::Contact.find(@task.actionable_item_id)
        end
      end
      if !@task.actionable_item_type.blank?
        params[:filter_type] = @task.actionable_item_type
        params[:filter_id] = @task.actionable_item_id
      end
      respond_to do |format|
        if @succ_task
          @updated_task = @task
          format.html { redirect_to rules_user_tasks_path }
          format.json { render status: :created, location: @task }
        else
          # message = "There were errors creating the task: #{@task.errors.full_messages.join('<br/>')}"
          # flash[:error] = message
          # TODO: we shouldn't be doing this.  We should refresh the view form
          # instead, and let simpleform handle the errors.
          format.html { render  "new" }
          format.json do
            render json: { errors: @task.errors },
                   status: :unprocessable_entity
          end
        end
      end
    end

    def edit
      @contact   = current_user.contacts
      @task = current_user.tasks.find(params[:id])
      respond_to do |format|
        format.html
        format.js {render "show"}
      end
    end

    def update
      @task = current_user.tasks.find(params[:id])
      due_date = params[:rules_user_task].delete(:due_date)
      if !due_date.blank?
        due_date = Date.strptime(due_date, "%m/%d/%Y") if due_date.present?
        @task.completed_at = nil if due_date > Date.current and @task.due_date != due_date
      end
      @task.due_date = due_date
      @task.assign_attributes(user_tasks_params)
      #@contact=current_user.contacts

      if !@task.actionable_item_type.blank?
        params[:filter_type] = @task.actionable_item_type
        params[:filter_id] = @task.actionable_item_id
      end
      respond_to do |format|
        if @task.save
          @updated_task = @task
          format.html { redirect_back fallback_location: root_path }
          format.json { render location: @task, status: :ok }
        else
          format.html {render  "edit" }
          format.json { render template: '/rules/user_tasks/errors.json.jbuilder', status: :unprocessable_entity }
          format.js {render :create, locals: {update: true}}
        end
      end
    end

    def destroy
      @task = current_user.tasks.find(params[:id])
      @task.destroy
      @extra_params = eval(params[:extra_params]) unless params[:extra_params].blank?
      respond_to do |format|
        format.html do
          redirect_to(:back, {
                      params: {
                        filter_type: params[:filter_type],
                        filter_id: params[:filter_id]},
                        notice: "Task was successfully Deleted"
                      })
        end
        format.js do
          render 'destroy'
        end
        format.json do
          @success = current_user.tasks.find(params[:id]).count == 0
          render status: 200
        end
      end
    end

    def copy_to_calendar
      unless params[:task].blank?
         @tasks=current_user.tasks.find_all_by_id(params[:task])
         @tasks.each do |g|
          @copy_task=g.dup
          @copy_task.calendar_id = params[:copy_to]
          @copy_task.save
         end
      end

      redirect_to rules_user_tasks_path ,notice: "Tasks were successfully Copied"

    end


    #simple toggle for mobile api
    def toggle_completion
      @task = Rules::Task.find_by(user_id: current_user, id: params[:id])
      if @task.completed?
        @task.completed_at = nil
      elsif !@task.completed?
        @task.completed_at = Time.now
      end
      @task.save

      respond_to do |format|
        format.js
        format.json {render status: 200}
      end
    end

    def completed_tasks
      @task = Rules::Task.where("id in (?)",params[:id].split(",").map(&:to_i))
      unless @task.nil?
        flash[:notice] = if(params["type"] == "complete")
          "Task has been marked complete"
        else
          "Task has been marked incomplete"
        end
        value = (params["type"] == "complete") ? Time.now : nil
        # Calling update_all on a scope will skip the Rules engine
        # Do individual updates, not @task.update_all(completed_at: value)
        @task.each do |t|
          t.completed_at = value
          t.save
          notification = t.user.notifications.where("item_id = ? and item_type = ? ", t.id, "Rules::Task").first
          unless notification.blank?
            notification.seen = notification.mark_seen
            notification.save
          end
        end
        @updated_task = @task
      end
      respond_to do |format|
       format.html { redirect_back fallback_location: root_path }
        #this should be needed, mobile api is using toggle_completion
        format.json { render status: 200 }
      end
    end

    private
      def user_tasks_params
        params.require(:rules_user_task)
              .permit(:actionable_item_id,
                      :actionable_item_type,
                      :attach_to,
                      :calendar_id,
                      :days_to_complete,
                      :description,
                      :due_date,
                      :priority,
                      :reminders_attributes,
                      :source,
                      :status,
                      :task_id,
                      :task_title,
                      :user_id)
      end

      def _index
        if request.format == :json
          order = params[:order] ||= "ASC"
          @tasks = case params[:type]
          when "complete"
            sort = params[:sort] ||= "completed_at"
            current_user.tasks.completed.order("#{sort} #{order}")
          when "incomplete"
            sort = params[:sort] ||= "due_date"
            current_user.tasks.open.order("#{sort} #{order}")
          when "overdue"
            sort = params[:sort] ||= "due_date"
            current_user.tasks.overdue.order("#{sort} #{order}")
          when "today"
            sort = params[:sort] ||= "priority"
            current_user.tasks.due_today.order("#{sort} #{order}")
          when "future"
            sort = params[:sort] ||= "due_date"
            current_user.tasks.future.order("#{sort} #{order}")
          when "no_date"
            sort = params[:sort] ||= "created_at"
            current_user.tasks.no_due_date.order("#{sort} #{order}")
          when "complete_incomplete"
            sort = params[:sort] ||= "created_at"
            current_user.tasks.completed.order("#{sort} #{order}") +
            current_user.tasks.open.order("#{sort} #{order}")
          else
            sort = params[:sort] ||= "created_at"
            current_user.tasks.order("#{sort} #{order}")
          end
          #getting an ActiveRecord::Relation object so page and where can be called on it
          @tasks = Rules::Task.where(id: @tasks.map(&:id)) if @tasks.is_a?(Array)

          if params[:search]
            sort = params[:sort] ||= "created_at"
            q = "%#{params[:search]}%"
            @tasks = @tasks.where("rules_tasks.task_title like ? or rules_tasks.description like ?", q, q).order("#{sort} #{order}")
          end

          @tasks = @tasks.page(params[:page]).per(params[:limit])
        else
          # @tasks_due_today, @tasks_overdue, @future_tasks, @incomplete_tasks, @no_due_date, @completed_incomplete_tasks, @completed_tasks = Rules::Task.view_tasks_by_type(current_user, params[:type])
          @tasks = case params[:type]
          when "complete"
            current_user.tasks.completed
          when "open", "incomplete"
            current_user.tasks.open 
          end
        end
      end
  end
end