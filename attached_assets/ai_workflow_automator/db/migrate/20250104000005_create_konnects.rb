class CreateKonnects < ActiveRecord::Migration[7.0]
  def up
    create_table :konnects do |t|
      t.string :name, null: false
      t.text :description
      t.references :left_app, null: false, foreign_key: { to_table: :apps }
      t.references :right_app, null: false, foreign_key: { to_table: :apps }
      t.references :left_app_event, null: false, foreign_key: { to_table: :app_events }
      t.references :right_app_event, null: false, foreign_key: { to_table: :app_events }
      t.json :config
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :konnects, :active
    add_index :konnects, [:left_app_id, :right_app_id]
  end

  def down
    drop_table :konnects
  end
end