class Api::V1::PublicController < ApplicationController
  skip_before_action :authenticate_api_key!, only: [:public_app_list, :public_events]

  def public_app_list
    apps = App.active.select(:id, :name, :description, :category, :service_name)
    render_success(apps)
  end

  def public_events
    app_id = params[:app_id]
    
    if app_id.present?
      app = App.find(app_id)
      events = app.app_events.active.select(:id, :name, :description, :event_type)
      render_success(events)
    else
      events = AppEvent.active.includes(:app).select(:id, :name, :description, :event_type, :app_id)
      render_success(events.as_json(include: { app: { only: [:id, :name] } }))
    end
  rescue ActiveRecord::RecordNotFound
    render_error('App not found', :not_found)
  end
end
