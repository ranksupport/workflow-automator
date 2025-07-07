class CreateAppEvents < ActiveRecord::Migration[7.0]
  def up
    create_table :app_events do |t|
      t.references :app, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :event_type, null: false # 'trigger' or 'action'
      t.boolean :active, default: true
      t.json :metadata
      t.timestamps
    end

    add_index :app_events, [:app_id, :event_type]
    add_index :app_events, :active
  end

  def down
    drop_table :app_events
  end
end