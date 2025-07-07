class CreateAppEventConfigs < ActiveRecord::Migration[7.0]
  def up
    create_table :app_event_configs do |t|
      t.references :app_event, null: false, foreign_key: true
      t.string :field_name, null: false
      t.string :field_type, null: false
      t.boolean :required, default: false
      t.text :description
      t.string :default_value
      t.json :validation_rules
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :app_event_configs, [:app_event_id, :field_name]
    add_index :app_event_configs, :active
  end

  def down
    drop_table :app_event_configs
  end
end