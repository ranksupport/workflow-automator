class AddMissingFieldsToAppEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :app_events, :side, :string
    add_column :app_events, :event_hook, :string
    add_column :app_events, :event_names, :string
    add_column :app_events, :webhook_type, :string
  end
end
