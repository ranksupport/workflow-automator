class AddMissingFieldsToAppEventConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :app_event_configs, :app_id, :integer
    add_column :app_event_configs, :sequence, :integer, default: 0
    add_column :app_event_configs, :config_key, :string
    add_column :app_event_configs, :config_key_required, :boolean, default: false
    add_column :app_event_configs, :service_name, :string
    add_column :app_event_configs, :side, :string
    add_column :app_event_configs, :key_value_type, :string
    add_column :app_event_configs, :label, :string
    add_column :app_event_configs, :fetch_fields, :boolean, default: false
  end
end
