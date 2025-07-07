class CreateSampleData < ActiveRecord::Migration[7.0]
  def up
    # Create API key if it doesn't exist
    unless ApiKey.exists?(key: '8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e')
      ApiKey.create!(
        key: '8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e',
        name: 'Default API Key',
        description: 'Default API key for testing',
        active: true
      )
    end

    # Create sample app if it doesn't exist
    unless App.exists?(service_name: 'rebrandly')
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

      # Create a sample konnect
      Konnect.create!(
        name: 'Test Konnect',
        description: 'Sample workflow for testing',
        left_app: app,
        right_app: app,
        left_app_event: event,
        right_app_event: event,
        config: { test: true },
        active: true
      )
    end
  end

  def down
    # Remove sample data
    ApiKey.where(key: '8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e').destroy_all
    App.where(service_name: 'rebrandly').destroy_all
  end
end