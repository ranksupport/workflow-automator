require 'sinatra'
require 'sinatra/activerecord'
require 'rack/cors'
require 'httparty'
require 'json'
require 'jwt'

# CORS Configuration
use Rack::Cors do
  allow do
    origins '*'
    resource '*',
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end

# Database configuration
set :database_url, ENV['DATABASE_URL'] || 'sqlite3:database.sqlite3'

# Load models
require_relative 'app/models/application_record'
require_relative 'app/models/api_key'
require_relative 'app/models/app'
require_relative 'app/models/app_event'
require_relative 'app/models/app_event_config'
require_relative 'app/models/konnect'
require_relative 'app/models/service/base_service'
require_relative 'app/models/service/rebrandly'
require_relative 'app/services/external_app_service_executor'

# API Key Authentication Middleware
class ApiKeyAuthentication
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Skip authentication for public endpoints and health check
    if public_endpoint?(request.path) || health_check?(request.path)
      return @app.call(env)
    end

    # Check for API key in headers or params
    api_key = request.env['HTTP_X_API_KEY'] || request.params['api_key']
    
    unless valid_api_key?(api_key)
      return unauthorized_response
    end

    # Set the API key in the environment for routes to use
    env['api_key'] = api_key
    @app.call(env)
  end

  private

  def public_endpoint?(path)
    public_paths = [
      '/api/v1/public/app_list',
      '/api/v1/public/events'
    ]
    
    public_paths.any? { |public_path| path.start_with?(public_path) }
  end

  def health_check?(path)
    path == '/health'
  end

  def valid_api_key?(key)
    return false unless key && !key.empty?
    
    # Check if API key exists and is active
    ApiKey.find_by(key: key, active: true).present?
  rescue
    false
  end

  def unauthorized_response
    [
      401,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Invalid or missing API key', status: 'unauthorized' }.to_json]
    ]
  end
end

use ApiKeyAuthentication

# Helper methods
helpers do
  def render_success(data = {}, message = 'Success')
    content_type :json
    {
      status: 'success',
      message: message,
      data: data
    }.to_json
  end

  def render_error(message, status = 400, data = {})
    halt status, {
      'Content-Type' => 'application/json'
    }, {
      status: 'error',
      message: message,
      data: data
    }.to_json
  end

  def current_api_key
    api_key_value = request.env['HTTP_X_API_KEY'] || params[:api_key]
    if api_key_value
      ApiKey.find_by(key: api_key_value, active: true)
    end
  end
end

# Routes

# Health check
get '/health' do
  'OK'
end

# Public endpoints (no API key required)
get '/api/v1/public/app_list' do
  apps = App.where(active: true).select(:id, :name, :description, :category, :service_name)
  render_success(apps)
end

get '/api/v1/public/events' do
  app_id = params[:app_id]
  
  if app_id.present?
    app = App.find(app_id)
    events = app.app_events.where(active: true).select(:id, :name, :description, :event_type)
    render_success(events)
  else
    events = AppEvent.includes(:app).where(active: true)
    formatted_events = events.map do |event|
      {
        id: event.id,
        name: event.name,
        description: event.description,
        event_type: event.event_type,
        app_id: event.app_id,
        app_name: event.app.name
      }
    end
    render_success(formatted_events)
  end
rescue ActiveRecord::RecordNotFound
  render_error('App not found', 404)
end

# External API endpoints (API key required)
get '/api/v1/external/app/:app_id/events' do
  app = App.find(params[:app_id])
  events = app.app_events.includes(:app_event_configs).where(active: true)
  formatted_events = events.map do |event|
    {
      id: event.id,
      app_id: event.app_id,
      name: event.name,
      description: event.description,
      event_type: event.event_type,
      active: event.active,
      metadata: event.metadata,
      created_at: event.created_at,
      updated_at: event.updated_at,
      app_event_configs: event.app_event_configs.map do |config|
        {
          id: config.id,
          field_name: config.field_name,
          field_type: config.field_type,
          required: config.required,
          description: config.description,
          default_value: config.default_value
        }
      end
    }
  end
  render_success(formatted_events)
rescue ActiveRecord::RecordNotFound
  render_error('App not found', 404)
end

post '/api/v1/external/execute/:service_name' do
  service_name = params[:service_name]
  
  # Parse JSON body if present
  request_body = request.body.read
  if request_body && !request_body.empty?
    begin
      json_params = JSON.parse(request_body)
      action_params = json_params
    rescue JSON::ParserError
      action_params = {}
    end
  else
    action_params = params.reject { |k, v| %w[splat captures service_name api_key].include?(k) }
  end

  begin
    service_class = service_name.classify.constantize
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

post '/api/v1/external/trigger' do
  # Parse JSON body if present
  request_body = request.body.read
  if request_body && !request_body.empty?
    begin
      json_params = JSON.parse(request_body)
      service_name = json_params['service_name'] || params[:service_name]
      action_name = json_params['action_name'] || params[:action_name]
      config_params = json_params['config'] || params[:config] || {}
    rescue JSON::ParserError
      service_name = params[:service_name]
      action_name = params[:action_name]
      config_params = params[:config] || {}
    end
  else
    service_name = params[:service_name]
    action_name = params[:action_name]
    config_params = params[:config] || {}
  end

  render_error('Service name is required') unless service_name && !service_name.empty?

  begin
    result = ExternalAppServiceExecutor.execute(service_name, action_name, config_params)
    render_success(result)
  rescue => e
    render_error("Service execution failed: #{e.message}")
  end
end

post '/api/v1/external/test_and_review' do
  # Parse JSON body if present
  request_body = request.body.read
  if request_body && !request_body.empty?
    begin
      json_params = JSON.parse(request_body)
      merged_params = params.merge(json_params)
    rescue JSON::ParserError
      merged_params = params
    end
  else
    merged_params = params
  end
  
  if merged_params[:left_app_id] && !merged_params[:left_app_id].to_s.empty?
    left_app_trigger_test_event(merged_params)
  else
    begin
      konnect = Konnect.find(merged_params[:konnect_id])
      return render_error('Konnect not found', 404) unless konnect
      
      # Simple test execution - you can expand this based on your needs
      config = merged_params[:config] || merged_params['config'] || {}
      
      content_type :json
      {
        konnect_id: konnect.id,
        konnect_activity_id: merged_params[:konnect_activity_id] || merged_params['konnect_activity_id'],
        config_fields: config,
        raw_response: { "test": "success", "config": config },
        error: nil,
        errors: [],
        test_status: "Success"
      }.to_json
    rescue ActiveRecord::RecordNotFound
      render_error('Konnect not found', 404)
    rescue => e
      content_type :json
      {
        konnect_id: merged_params[:konnect_id] || merged_params['konnect_id'],
        konnect_activity_id: merged_params[:konnect_activity_id] || merged_params['konnect_activity_id'],
        config_fields: merged_params[:config] || merged_params['config'],
        raw_response: {},
        error: e.message,
        errors: [],
        test_status: "Failure"
      }.to_json
    end
  end
end

def left_app_trigger_test_event(params)
  begin
    app = App.find(params[:left_app_id])
    event = app.app_events.find(params[:left_app_event_id])
    
    service_class = app.service_name.classify.constantize
    service_instance = service_class.new
    
    result = service_instance.test_trigger(event, params[:config] || {})
    content_type :json
    {
      app_id: app.id,
      event_id: event.id,
      raw_response: result,
      test_status: "Success"
    }.to_json
  rescue => e
    content_type :json
    {
      app_id: params[:left_app_id],
      event_id: params[:left_app_event_id],
      raw_response: {},
      error: e.message,
      test_status: "Failure"
    }.to_json
  end
end

# Initialize database with sample data if not exists
before_first_request do
  unless ApiKey.exists?
    # Create default API key
    ApiKey.create!(
      key: '8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e',
      name: 'Default API Key',
      description: 'Default API key for testing',
      active: true
    )

    # Create sample app
    app = App.create!(
      name: 'Rebrandly',
      description: 'URL shortening service',
      category: 'Productivity',
      service_name: 'rebrandly',
      active: true
    )

    # Create sample app event
    event = app.app_events.create!(
      name: 'create_link',
      description: 'Create a shortened link',
      event_type: 'action',
      active: true
    )

    # Create sample app event configs
    event.app_event_configs.create!([
      {
        field_name: 'destination',
        field_type: 'string',
        required: true,
        description: 'The URL to shorten'
      },
      {
        field_name: 'slashtag',
        field_type: 'string',
        required: false,
        description: 'Custom slashtag for the shortened URL'
      }
    ])
  end
end