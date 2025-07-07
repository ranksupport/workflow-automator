class CreateApps < ActiveRecord::Migration[7.0]
  def up
    create_table :apps do |t|
      t.string :name, null: false
      t.text :description
      t.string :category
      t.string :service_name, null: false
      t.string :icon_url
      t.boolean :active, default: true
      t.json :metadata
      t.timestamps
    end

    add_index :apps, :service_name
    add_index :apps, :active
    add_index :apps, :category
  end

  def down
    drop_table :apps
  end
end