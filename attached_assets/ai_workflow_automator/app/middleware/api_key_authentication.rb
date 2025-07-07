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

    # Set the API key in the environment for controllers to use
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
    
    # Simple validation - in production you might want to cache this
    ApiKey.exists?(key: key, active: true)
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
