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
