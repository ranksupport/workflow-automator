class Api::V1::ExternalController < ApplicationController
  #before_action :authenticate_api_key!
  skip_before_action :authenticate_api_key!, only: [:public_app_list, :public_events]

  def trigger_service
    service_name = params[:service_name]
    action_name = params[:action_name]
    config_params = params[:config] || {}

    unless service_name.present?
      return render_error('Service name is required')
    end

    begin
      result = ExternalAppServiceExecutor.execute(service_name, action_name, config_params)
      render_success(result)
    rescue => e
      render_error("Service execution failed: #{e.message}")
    end
  end

  def test_and_review
    if params[:left_app_id].present?
      left_app_trigger_test_event(params)
    else
      begin
        konnect = Konnect.find(params[:konnect_id])
        raw_response = konnect.create_right_app_activity(params, current_api_key)
        render json: raw_response
      rescue Exception => e
        render json: {
          konnect_id: params[:konnect_id],
          konnect_activity_id: params[:konnect_activity_id],
          config_fields: params[:config],
          raw_response: {},
          error: e.message,
          errors: [],
          test_status: "Failure",
        }
      end
    end
  end

  def list_apps
    apps = App.active.includes(:app_events)
    render_success(apps.as_json(include: :app_events))
  end

  def list_app_events
    app = App.find(params[:app_id])
    events = app.app_events.active
    render_success(events.as_json(include: :app_event_configs))
  rescue ActiveRecord::RecordNotFound
    render_error('App not found', :not_found)
  end

  def execute_service
    service_name = params[:service_name]
    action_params = params.except(:controller, :action, :service_name, :api_key)

    begin
      service_class = "#{service_name.classify}".constantize
      service_instance = service_class.new
      
      if service_instance.respond_to?(:execute)
        result = service_instance.execute(action_params)
        render_success(result)
      else
        render_error("Service #{service_name} does not support execute method")
      end
    rescue NameError
      render_error("Service #{service_name} not found")
    rescue => e
      render_error("Service execution failed: #{e.message}")
    end
  end

  private

  def left_app_trigger_test_event(params)
    app = App.find(params[:left_app_id])
    event = app.app_events.find(params[:left_app_event_id])
    
    begin
      service_class = "#{app.service_name.classify}".constantize
      service_instance = service_class.new
      
      result = service_instance.test_trigger(event, params[:config] || {})
      render json: {
        app_id: app.id,
        event_id: event.id,
        raw_response: result,
        test_status: "Success"
      }
    rescue => e
      render json: {
        app_id: app.id,
        event_id: event.id,
        raw_response: {},
        error: e.message,
        test_status: "Failure"
      }
    end
  end
end
