require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module WorkflowAutomationApi
  class Application < Rails::Application
    config.load_defaults 7.0

    # API only mode
    config.api_only = true

    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
                 headers: :any,
                 methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end

    # Custom middleware for API key authentication
    config.middleware.use 'ApiKeyAuthentication'

    # Time zone
    config.time_zone = 'UTC'

    # Autoload paths
    config.autoload_paths += %W(#{config.root}/app/models/service)
    config.autoload_paths += %W(#{config.root}/app/services)
  end
end
