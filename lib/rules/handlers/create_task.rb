class Rules::Handlers::CreateTask < Rules::Handlers::CreateModel

  # Provide a continuation strategy to allow the ActionChain to not be processed any further 
  # until the resulting UserTask (in this case) is marked completed
  set_continuation_strategy Rules::Handlers::TaskCompletedStrategy

  needs :owner, :user                 # CreateModel base class will automatically map this to user property of UserTask
  needs :regarding, :object, optional: true     

  needs :actionable_url, :string, optional: true
  
  needs :due_in, :select, default: "1 day", values: ["1 day", "2 days", "3 days", "1 week", "2 weeks", "1 month", "30 days", "60 days", "90 days"]

  # optional :

  template :title
  template :description

  # This is required by PyrRules::Handlers::CreateModel
  def model_class
    Rules::Task
  end

  def set_model_props(m)
    m.item = regarding
    m.actionable_url = actionable_url
    #m.source = "system"
    m.title = eval_template(:title)
    m.description = eval_template(:description)
    period = eval( due_in.gsub(' ', '.'))
    m.due_date = period.from_now                   
  end

end