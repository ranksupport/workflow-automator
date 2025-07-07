class Konnect < ApplicationRecord
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
