class Rules::Handlers::TaskCompletedStrategy
  include Rules::Handlers::ContinuationStrategy

    set_title "Continue after Task is marked completed"
    set_icon "fa fa-user"

    # Trigger and criteria to process continuation of DeferredActionChain
    set_trigger "Rules::Task::update"
    set_criteria ({ event: "self[:changes]['completed_at'] && self[:changes]['completed_at'][0].blank? && !self[:changes]['completed_at'][1].blank?"})

end