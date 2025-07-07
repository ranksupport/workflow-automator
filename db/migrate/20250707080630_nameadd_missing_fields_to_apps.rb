class NameaddMissingFieldsToApps < ActiveRecord::Migration[7.0]
  def change
    add_column :apps, :authorization_url, :text
    add_column :apps, :app_client_key, :string
    add_column :apps, :app_secret, :string
    add_column :apps, :provider, :string
    add_column :apps, :webhook_enabled, :boolean, default: false
    add_column :apps, :webhook_instructions, :text
    add_column :apps, :status, :string
    add_column :apps, :app_type, :string
    add_column :apps, :category_tags, :string
  end
end
