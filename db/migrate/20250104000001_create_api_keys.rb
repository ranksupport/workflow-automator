class CreateApiKeys < ActiveRecord::Migration[7.0]
  def up
    create_table :api_keys do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :api_keys, :key, unique: true
    add_index :api_keys, [:active, :key]
  end

  def down
    drop_table :api_keys
  end
end