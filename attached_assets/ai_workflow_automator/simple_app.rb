require 'sinatra'
require 'rack/cors'
require 'httparty'
require 'json'
require 'jwt'
require 'sqlite3'

# CORS Configuration
use Rack::Cors do
  allow do
    origins '*'
    resource '*',
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end

# Database setup
DB = SQLite3::Database.new('database.sqlite3')
DB.results_as_hash = true

# Initialize database tables
def initialize_database
  DB.execute <<-SQL
    CREATE TABLE IF NOT EXISTS api_keys (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      description TEXT,
      active BOOLEAN DEFAULT 1,
      last_used_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL

  DB.execute <<-SQL
    CREATE TABLE IF NOT EXISTS apps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      category TEXT,
      service_name TEXT NOT NULL,
      icon_url TEXT,
      active BOOLEAN DEFAULT 1,
      metadata TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL

  DB.execute <<-SQL
    CREATE TABLE IF NOT EXISTS app_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      app_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      event_type TEXT NOT NULL,
      active BOOLEAN DEFAULT 1,
      metadata TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (app_id) REFERENCES apps (id)
    );
  SQL

  DB.execute <<-SQL
    CREATE TABLE IF NOT EXISTS app_event_configs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      app_event_id INTEGER NOT NULL,
      field_name TEXT NOT NULL,
      field_type TEXT NOT NULL,
      required BOOLEAN DEFAULT 0,
      description TEXT,
      default_value TEXT,
      validation_rules TEXT,
      active BOOLEAN DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (app_event_id) REFERENCES app_events (id)
    );
  SQL

  DB.execute <<-SQL
    CREATE TABLE IF NOT EXISTS konnects (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      left_app_id INTEGER NOT NULL,
      right_app_id INTEGER NOT NULL,
      left_app_event_id INTEGER NOT NULL,
      right_app_event_id INTEGER NOT NULL,
      config TEXT,
      active BOOLEAN DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (left_app_id) REFERENCES apps (id),
      FOREIGN KEY (right_app_id) REFERENCES apps (id),
      FOREIGN KEY (left_app_event_id) REFERENCES app_events (id),
      FOREIGN KEY (right_app_event_id) REFERENCES app_events (id)
    );
  SQL

  # Create a sample API key if none exists
  keys = DB.execute("SELECT COUNT(*) as count FROM api_keys")
  if keys[0]['count'] == 0
    api_key = SecureRandom.hex(32)
    DB.execute("INSERT INTO api_keys (key, name, description) VALUES (?, ?, ?)", 
               [api_key, "Default API Key", "Default API key for testing"])
    puts "Created default API key: #{api_key}"
  end

  # Create sample app if none exists
  apps = DB.execute("SELECT COUNT(*) as count FROM apps")
  if apps[0]['count'] == 0
    DB.execute("INSERT INTO apps (name, description, category, service_name) VALUES (?, ?, ?, ?)", 
               ["Rebrandly", "URL shortening service", "Productivity", "rebrandly"])
    
    app_id = DB.last_insert_row_id
    DB.execute("INSERT INTO app_events (app_id, name, description, event_type) VALUES (?, ?, ?, ?)", 
               [app_id, "create_link", "Create a shortened link", "action"])
    
    event_id = DB.last_insert_row_id
    DB.execute("INSERT INTO app_event_configs (app_event_id, field_name, field_type, required, description) VALUES (?, ?, ?, ?, ?)", 
               [event_id, "destination", "string", 1, "The URL to shorten"])
    DB.execute("INSERT INTO app_event_configs (app_event_id, field_name, field_type, required, description) VALUES (?, ?, ?, ?, ?)", 
               [event_id, "slashtag", "string", 0, "Custom slashtag for the shortened URL"])
    
    puts "Created sample Rebrandly app and events"
  end
end

initialize_database

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
    result = DB.execute("SELECT COUNT(*) as count FROM api_keys WHERE key = ? AND active = 1", [key])
    result[0]['count'] > 0
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
    case event['name'].downcase
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
      raise "Unknown event: #{event['name']}"
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
    
    if @action_name && !@action_name.empty?
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
    # Check if the service has available_actions method and validate the action
    if service_instance.respond_to?(:available_actions)
      available_actions = service_instance.available_actions
      unless available_actions.include?(@action_name)
        raise "Action '#{@action_name}' not available for service '#{@service_name}'. Available actions: #{available_actions.join(', ')}"
      end
    end

    # If service has an execute method, use it with the action parameter
    if service_instance.respond_to?(:execute)
      params_with_action = @params.merge('action' => @action_name)
      service_instance.execute(params_with_action)
    # Otherwise try to call the action method directly
    elsif service_instance.respond_to?(@action_name)
      service_instance.send(@action_name, @params)
    else
      raise "Service '#{@service_name}' does not support action '#{@action_name}'"
    end
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
    api_key = request.env['HTTP_X_API_KEY'] || params[:api_key]
    if api_key
      result = DB.execute("SELECT * FROM api_keys WHERE key = ? AND active = 1", [api_key])
      result.first
    end
  end

  def left_app_trigger_test_event(params)
    app = DB.execute("SELECT * FROM apps WHERE id = ?", [params[:left_app_id]]).first
    event = DB.execute("SELECT * FROM app_events WHERE id = ?", [params[:left_app_event_id]]).first
    
    return render_error('App not found', 404) unless app
    return render_error('Event not found', 404) unless event
    
    begin
      service_class = Object.const_get(app['service_name'].capitalize)
      service_instance = service_class.new
      
      result = service_instance.test_trigger(event, params[:config] || {})
      content_type :json
      {
        app_id: app['id'],
        event_id: event['id'],
        raw_response: result,
        test_status: "Success"
      }.to_json
    rescue => e
      content_type :json
      {
        app_id: app['id'],
        event_id: event['id'],
        raw_response: {},
        error: e.message,
        test_status: "Failure"
      }.to_json
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
  apps = DB.execute("SELECT id, name, description, category, service_name FROM apps WHERE active = 1")
  render_success(apps)
end

get '/api/v1/public/events' do
  app_id = params[:app_id]
  
  if app_id && !app_id.empty?
    app = DB.execute("SELECT * FROM apps WHERE id = ?", [app_id]).first
    return render_error('App not found', 404) unless app
    
    events = DB.execute("SELECT id, name, description, event_type FROM app_events WHERE app_id = ? AND active = 1", [app_id])
    render_success(events)
  else
    events = DB.execute(<<-SQL)
      SELECT ae.id, ae.name, ae.description, ae.event_type, ae.app_id, a.name as app_name
      FROM app_events ae
      JOIN apps a ON ae.app_id = a.id
      WHERE ae.active = 1
    SQL
    render_success(events)
  end
end

# External API endpoints (API key required)
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
      konnect = DB.execute("SELECT * FROM konnects WHERE id = ?", [merged_params[:konnect_id]]).first
      return render_error('Konnect not found', 404) unless konnect
      
      right_app_event = DB.execute("SELECT * FROM app_events WHERE id = ?", [konnect['right_app_event_id']]).first
      return render_error('Right app event not found', 404) unless right_app_event
      
      right_app = DB.execute("SELECT * FROM apps WHERE id = ?", [konnect['right_app_id']]).first
      return render_error('Right app not found', 404) unless right_app
      
      config = merged_params[:config] || merged_params['config'] || {}
      
      # Execute the right app action with provided config
      service_class = Object.const_get(right_app['service_name'].capitalize)
      service_instance = service_class.new
      result = service_instance.execute_event(right_app_event, config)
      
      content_type :json
      {
        konnect_id: konnect['id'],
        konnect_activity_id: merged_params[:konnect_activity_id] || merged_params['konnect_activity_id'],
        config_fields: config,
        raw_response: result,
        error: nil,
        errors: [],
        test_status: "Success"
      }.to_json
    rescue => e
      content_type :json
      {
        konnect_id: merged_params[:konnect_id] || merged_params['konnect_id'],
        konnect_activity_id: merged_params[:konnect_activity_id] || merged_params['konnect_activity_id'],
        config_fields: merged_params[:config] || merged_params['config'],
        raw_response: {},
        error: e.message,
        errors: [],
        test_status: "Failure",
      }.to_json
    end
  end
end

get '/api/v1/external/apps' do
  apps = DB.execute(<<-SQL)
    SELECT a.*, 
           json_group_array(
             json_object(
               'id', ae.id,
               'name', ae.name,
               'description', ae.description,
               'event_type', ae.event_type,
               'active', ae.active
             )
           ) as app_events
    FROM apps a
    LEFT JOIN app_events ae ON a.id = ae.app_id AND ae.active = 1
    WHERE a.active = 1
    GROUP BY a.id
  SQL
  
  # Parse the JSON app_events for each app
  apps.each do |app|
    app['app_events'] = JSON.parse(app['app_events'] || '[]')
  end
  
  render_success(apps)
end

get '/api/v1/external/app/:app_id/events' do
  app = DB.execute("SELECT * FROM apps WHERE id = ?", [params[:app_id]]).first
  return render_error('App not found', 404) unless app
  
  events = DB.execute(<<-SQL, [params[:app_id]])
    SELECT ae.*, 
           json_group_array(
             json_object(
               'id', aec.id,
               'field_name', aec.field_name,
               'field_type', aec.field_type,
               'required', aec.required,
               'description', aec.description,
               'default_value', aec.default_value
             )
           ) as app_event_configs
    FROM app_events ae
    LEFT JOIN app_event_configs aec ON ae.id = aec.app_event_id AND aec.active = 1
    WHERE ae.app_id = ? AND ae.active = 1
    GROUP BY ae.id
  SQL
  
  # Parse the JSON app_event_configs for each event
  events.each do |event|
    event['app_event_configs'] = JSON.parse(event['app_event_configs'] || '[]')
  end
  
  render_success(events)
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