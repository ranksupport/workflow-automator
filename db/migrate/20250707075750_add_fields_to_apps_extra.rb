class AddFieldsToAppsExtra < ActiveRecord::Migration[7.0]
  def change
    add_column :apps, :side, :string
    add_column :apps, :background_color, :string
    add_column :apps, :webhook_type, :string
    add_column :apps, :image_file_name, :string
    add_column :apps, :image_content_type, :string
    add_column :apps, :image_file_size, :integer
    add_column :apps, :image_updated_at, :datetime
    # Add others as needed
  end
end
