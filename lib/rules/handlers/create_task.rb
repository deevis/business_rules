class Rules::Handlers::CreateTask < Rules::Handlers::CreateModel

  # Provide a continuation strategy to allow the ActionChain to not be processed any further 
  # until the resulting UserTask (in this case) is marked completed
  set_continuation_strategy Rules::Handlers::TaskCompletedStrategy

  needs :owner, :user                 # CreateModel base class will automatically map this to user property of UserTask
  needs :regarding, :object, optional: true     # This should really be optional once optional comes into existence

  needs :actionable_url, :string, optional: true
  
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
    m.due_date = 1.day.from_now                   # TODO: make this configurable
  end

end