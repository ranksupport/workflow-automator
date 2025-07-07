class ApplicationController < ActionController::API
  before_action :authenticate_api_key!, except: [:health]

  private

  def authenticate_api_key!
    api_key = request.headers['X-API-KEY'] || params[:api_key]
    
    unless api_key.present? && valid_api_key?(api_key)
      render json: { error: 'Invalid or missing API key' }, status: :unauthorized
    end
  end

  def valid_api_key?(key)
    # Check if API key exists and is active
    ApiKey.find_by(key: key, active: true).present?
  end

  def current_api_key
    @current_api_key ||= ApiKey.find_by(key: request.headers['X-API-KEY'] || params[:api_key])
  end

  def render_success(data = {}, message = 'Success')
    render json: {
      status: 'success',
      message: message,
      data: data
    }
  end

  def render_error(message, status = :bad_request, data = {})
    render json: {
      status: 'error',
      message: message,
      data: data
    }, status: status
  end
end
