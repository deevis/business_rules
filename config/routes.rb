Rails.application.routes.draw do
  namespace :rules do

    resources :actions

    resources :rules do
      resources :actions
      collection do
        get :lookup_events
        get :lookup_actions
        get "lookup_class/:action_id/:action_field/:lookup_type", action: "lookup_class", as: "lookup_class"
        get "lookup_class_instance/:action_id/:action_field/:lookup_type/:klazz", action: "lookup_class_instance", as: "lookup_class_instance"
        get :lookup_sub_properties, defaults: {format: :js}
        get :reload_rules_engine
        get :fresh_start
        get :export
        get :dashboard
        get :notifications
        get :import
        post :import, action: "do_import"
        get :toggle_activity_channel_enabled, defaults: {format: :js}
      end
      member do
        get :show_action_configuration, defaults: {format: :js}
        get :add_action
        get :add_action_mapping
        get :add_event
        get :set_timer_event_class
        delete :remove_action
        delete :remove_action_mapping
        get :remove_action_mapping
        delete :remove_event
        get :show_yaml
        get :clone
        get :toggle_active, defaults: {format: :js}
        get :toggle_future_action
        get :toggle_defer_processing
        get :set_future_field, defaults: {format: :js}
        get :undelete
        get :move_action_upwards
        get :move_action_downwards
        get :test_rule
        get :dynamic_event_fields
        post :post_dynamic_event_fields
        get :validate_criteria, defaults: {format: :js}
      end
    end

    resources :events, :only => [:index, :show] do
      collection do 
        post :push_event
      end
      resources :rules do
        resources :actions
      end
    end
    
    resources :notifications do
      collection do
        get :mark_seen, defaults: { format: :js}
        get :mark_all_seen
      end
      member do
        get :toggle_dismissed, defaults: { format: :js}
      end
    end

    resources :tasks do
      collection do
        get :calendar
        get :completed_tasks
        get :priority
      end
      member do 
        get :toggle_completion, defaults: { format: :js}
      end
    end

    # match "/events", to: "rules#events", as: "events"
  end
end
