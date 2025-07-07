Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Public endpoints (no API key required)
      get 'public/app_list', to: 'public#public_app_list'
      get 'public/events', to: 'public#public_events'
      
      # External API endpoints (API key required)
      post 'external/trigger', to: 'external#trigger_service'
      post 'external/test_and_review', to: 'external#test_and_review'
      get 'external/apps', to: 'external#list_apps'
      get 'external/app/:app_id/events', to: 'external#list_app_events'
      post 'external/execute/:service_name', to: 'external#execute_service'
    end
  end

  # Health check
  get 'health', to: proc { [200, {}, ['OK']] }
end
