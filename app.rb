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
set :database_url, ENV['DATABASE_URL'] || 'sqlite3:///database.sqlite3'

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
    api_key = request.env['HTTP_X_API_KEY'] || 
              request.env['HTTP_X_API_KEY'.downcase] ||
              request.params['api_key']
    
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
    return false unless key.present?
    
    # Simple validation - check if API key exists and is active
    ApiKey.exists?(key: key, active: true)
  rescue => e
    puts "API Key validation error: #{e.message}"
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

# Models
class ApiKey < ActiveRecord::Base
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }

  before_create :generate_key

  def self.create_key(name, description = nil)
    create!(
      name: name,
      description: description,
      active: true
    )
  end

  def deactivate!
    update!(active: false)
  end

  def activate!
    update!(active: true)
  end

  private

  def generate_key
    self.key = SecureRandom.hex(32) if key.blank?
  end
end

class App < ActiveRecord::Base
  has_many :app_events, dependent: :destroy
  has_many :konnects, dependent: :destroy

  validates :name, presence: true
  validates :service_name, presence: true

  scope :active, -> { where(active: true) }

  def service_class
    "#{service_name.classify}".constantize
  rescue NameError
    nil
  end

  def service_instance
    service_class&.new
  end

  def available_actions
    service_instance&.available_actions || []
  end
end

class AppEvent < ActiveRecord::Base
  belongs_to :app
  has_many :app_event_configs, dependent: :destroy

  validates :name, presence: true
  validates :event_type, presence: true

  scope :active, -> { where(active: true) }
  scope :triggers, -> { where(event_type: 'trigger') }
  scope :actions, -> { where(event_type: 'action') }

  def config_fields
    app_event_configs.active.pluck(:field_name, :field_type, :required, :description)
  end

  def execute(config = {})
    app.service_instance&.execute_event(self, config)
  end
end

class AppEventConfig < ActiveRecord::Base
  belongs_to :app_event

  validates :field_name, presence: true
  validates :field_type, presence: true

  scope :active, -> { where(active: true) }
  scope :required, -> { where(required: true) }

  FIELD_TYPES = %w[string integer boolean array object].freeze

  validates :field_type, inclusion: { in: FIELD_TYPES }

  def validate_value(value)
    case field_type
    when 'string'
      value.is_a?(String)
    when 'integer'
      value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A\d+\z/))
    when 'boolean'
      [true, false].include?(value) || %w[true false].include?(value.to_s.downcase)
    when 'array'
      value.is_a?(Array)
    when 'object'
      value.is_a?(Hash)
    else
      true
    end
  end
end

class Konnect < ActiveRecord::Base
  belongs_to :left_app, class_name: 'App'
  belongs_to :right_app, class_name: 'App'
  belongs_to :left_app_event, class_name: 'AppEvent'
  belongs_to :right_app_event, class_name: 'AppEvent'

  validates :name, presence: true

  scope :active, -> { where(active: true) }

  def create_right_app_activity(params, user = nil)
    begin
      config = params[:config] || {}
      
      # Execute the right app action with provided config
      result = right_app_event.execute(config)
      
      {
        konnect_id: id,
        konnect_activity_id: params[:konnect_activity_id],
        config_fields: config,
        raw_response: result,
        error: nil,
        errors: [],
        test_status: "Success"
      }
    rescue => e
      {
        konnect_id: id,
        konnect_activity_id: params[:konnect_activity_id],
        config_fields: config,
        raw_response: {},
        error: e.message,
        errors: [e.message],
        test_status: "Failure"
      }
    end
  end

  def execute_workflow(trigger_data = {})
    # Execute the complete workflow from trigger to action
    begin
      # Process trigger data through left app
      processed_data = left_app_event.execute(trigger_data)
      
      # Execute right app action with processed data
      result = right_app_event.execute(processed_data)
      
      {
        status: 'success',
        trigger_data: trigger_data,
        processed_data: processed_data,
        result: result
      }
    rescue => e
      {
        status: 'error',
        error: e.message,
        trigger_data: trigger_data
      }
    end
  end
end

# Service Classes
class BaseService
  include HTTParty

  def initialize
    @api_key = self.class.api_key
    @base_url = self.class.base_url
  end

  def self.api_key
    ENV["#{self.name.upcase.gsub('::', '_')}_API_KEY"]
  end

  def self.base_url
    # Override in subclasses
    raise NotImplementedError, "#{self.name} must define base_url"
  end

  def available_actions
    # Override in subclasses to return available actions
    []
  end

  def execute(params = {})
    # Override in subclasses
    raise NotImplementedError, "#{self.class.name} must implement execute method"
  end

  def execute_event(event, config = {})
    # Override in subclasses
    raise NotImplementedError, "#{self.class.name} must implement execute_event method"
  end

  def test_trigger(event, config = {})
    # Override in subclasses for testing triggers
    execute_event(event, config)
  end

  protected

  def make_request(method, endpoint, options = {})
    url = "#{@base_url}#{endpoint}"
    options[:headers] ||= {}
    options[:headers]['Authorization'] = "Bearer #{@api_key}" if @api_key

    response = self.class.send(method, url, options)
    
    if response.success?
      response.parsed_response
    else
      raise "API request failed: #{response.code} - #{response.message}"
    end
  end

  def get(endpoint, options = {})
    make_request(:get, endpoint, options)
  end

  def post(endpoint, options = {})
    make_request(:post, endpoint, options)
  end

  def put(endpoint, options = {})
    make_request(:put, endpoint, options)
  end

  def delete(endpoint, options = {})
    make_request(:delete, endpoint, options)
  end
end

class Rebrandly < BaseService
  def self.base_url
    'https://api.rebrandly.com/v1'
  end

  def available_actions
    [
      'create_link',
      'get_link',
      'update_link',
      'delete_link',
      'list_links'
    ]
  end

  def execute(params = {})
    action = params[:action] || params['action']
    
    case action
    when 'create_link'
      create_link(params)
    when 'get_link'
      get_link(params)
    when 'update_link'
      update_link(params)
    when 'delete_link'
      delete_link(params)
    when 'list_links'
      list_links(params)
    else
      raise "Unknown action: #{action}"
    end
  end

  def execute_event(event, config = {})
    case event.name.downcase
    when 'create_link', 'shorten_url'
      create_link(config)
    when 'get_link', 'retrieve_link'
      get_link(config)
    when 'update_link'
      update_link(config)
    when 'delete_link'
      delete_link(config)
    when 'list_links'
      list_links(config)
    else
      raise "Unknown event: #{event.name}"
    end
  end

  private

  def create_link(params)
    payload = {
      destination: params[:destination] || params['destination'],
      slashtag: params[:slashtag] || params['slashtag'],
      title: params[:title] || params['title']
    }.compact

    raise "Destination URL is required" unless payload[:destination]

    post('/links', { body: payload.to_json, headers: { 'Content-Type' => 'application/json' } })
  end

  def get_link(params)
    link_id = params[:link_id] || params['link_id']
    raise "Link ID is required" unless link_id

    get("/links/#{link_id}")
  end

  def update_link(params)
    link_id = params[:link_id] || params['link_id']
    raise "Link ID is required" unless link_id

    payload = {
      destination: params[:destination] || params['destination'],
      slashtag: params[:slashtag] || params['slashtag'],
      title: params[:title] || params['title']
    }.compact

    put("/links/#{link_id}", { body: payload.to_json, headers: { 'Content-Type' => 'application/json' } })
  end

  def delete_link(params)
    link_id = params[:link_id] || params['link_id']
    raise "Link ID is required" unless link_id

    delete("/links/#{link_id}")
  end

  def list_links(params = {})
    query_params = {
      limit: params[:limit] || params['limit'] || 25,
      last: params[:last] || params['last']
    }.compact

    query_string = query_params.empty? ? '' : "?#{URI.encode_www_form(query_params)}"
    get("/links#{query_string}")
  end
end

# Service Executor
class ExternalAppServiceExecutor
  def self.execute(service_name, action_name = nil, params = {})
    new(service_name, action_name, params).execute
  end

  def initialize(service_name, action_name = nil, params = {})
    @service_name = service_name
    @action_name = action_name
    @params = params
  end

  def execute
    service_instance = load_service
    
    if @action_name.present?
      execute_specific_action(service_instance)
    else
      execute_general(service_instance)
    end
  end

  private

  def load_service
    service_class_name = @service_name.capitalize
    service_class = Object.const_get(service_class_name)
    service_class.new
  rescue NameError => e
    raise "Service '#{@service_name}' not found."
  end

  def execute_specific_action(service_instance)
    unless service_instance.respond_to?(@action_name)
      available_actions = service_instance.respond_to?(:available_actions) ? service_instance.available_actions : []
      raise "Action '#{@action_name}' not available for service '#{@service_name}'. Available actions: #{available_actions.join(', ')}"
    end

    service_instance.send(@action_name, @params)
  end

  def execute_general(service_instance)
    if service_instance.respond_to?(:execute)
      service_instance.execute(@params)
    else
      raise "Service '#{@service_name}' does not implement execute method"
    end
  end
end

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
    @current_api_key ||= ApiKey.find_by(key: request.env['HTTP_X_API_KEY'] || params[:api_key])
  end

  def left_app_trigger_test_event(params)
    app = App.find(params[:left_app_id])
    event = app.app_events.find(params[:left_app_event_id])
    
    begin
      service_class = Object.const_get(app.service_name.capitalize)
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
        app_id: app.id,
        event_id: event.id,
        raw_response: {},
        error: e.message,
        test_status: "Failure"
      }.to_json
    end
  end

  def parse_request_body
    request.body.rewind
    body = request.body.read
    return {} if body.empty?
    
    begin
      JSON.parse(body)
    rescue JSON::ParserError
      {}
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
  apps = App.active.select(:id, :name, :description, :category, :service_name)
  render_success(apps)
end

get '/api/v1/public/events' do
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
  render_error('App not found', 404)
end

# External API endpoints (API key required)
post '/api/v1/external/trigger' do
  json_params = parse_request_body
  
  service_name = json_params['service_name'] || params[:service_name]
  action_name = json_params['action_name'] || params[:action_name]
  config_params = json_params['config'] || params[:config] || {}

  render_error('Service name is required') unless service_name.present?

  begin
    result = ExternalAppServiceExecutor.execute(service_name, action_name, config_params)
    render_success(result)
  rescue => e
    render_error("Service execution failed: #{e.message}")
  end
end

post '/api/v1/external/test_and_review' do
  json_params = parse_request_body
  merged_params = params.merge(json_params)
  
  if merged_params[:left_app_id].present?
    left_app_trigger_test_event(merged_params)
  else
    begin
      konnect = Konnect.find(merged_params[:konnect_id])
      raw_response = konnect.create_right_app_activity(merged_params, current_api_key)
      content_type :json
      raw_response.to_json
    rescue Exception => e
      content_type :json
      {
        konnect_id: merged_params[:konnect_id],
        konnect_activity_id: merged_params[:konnect_activity_id],
        config_fields: merged_params[:config],
        raw_response: {},
        error: e.message,
        errors: [],
        test_status: "Failure",
      }.to_json
    end
  end
end

get '/api/v1/external/apps' do
  apps = App.active.includes(:app_events)
  render_success(apps.as_json(include: :app_events))
end

get '/api/v1/external/app/:app_id/events' do
  app = App.find(params[:app_id])
  events = app.app_events.active
  render_success(events.as_json(include: :app_event_configs))
rescue ActiveRecord::RecordNotFound
  render_error('App not found', 404)
end

post '/api/v1/external/execute/:service_name' do
  service_name = params[:service_name]
  json_params = parse_request_body
  action_params = json_params.empty? ? params.except('splat', 'captures', 'service_name', 'api_key') : json_params

  begin
    service_class = Object.const_get(service_name.capitalize)
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

# Configure server
configure do
  set :bind, '0.0.0.0'
  set :port, 5000
end