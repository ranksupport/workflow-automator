# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2025_07_07_081943) do
  create_table "api_keys", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "key"], name: "index_api_keys_on_active_and_key"
    t.index ["key"], name: "index_api_keys_on_key", unique: true
  end

  create_table "app_event_configs", force: :cascade do |t|
    t.integer "app_event_id", null: false
    t.string "field_name", null: false
    t.string "field_type", null: false
    t.boolean "required", default: false
    t.text "description"
    t.string "default_value"
    t.json "validation_rules"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "app_id"
    t.integer "sequence", default: 0
    t.string "config_key"
    t.boolean "config_key_required", default: false
    t.string "service_name"
    t.string "side"
    t.string "key_value_type"
    t.string "label"
    t.boolean "fetch_fields", default: false
    t.index ["active"], name: "index_app_event_configs_on_active"
    t.index ["app_event_id", "field_name"], name: "index_app_event_configs_on_app_event_id_and_field_name"
    t.index ["app_event_id"], name: "index_app_event_configs_on_app_event_id"
  end

  create_table "app_events", force: :cascade do |t|
    t.integer "app_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "event_type", null: false
    t.boolean "active", default: true
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "side"
    t.string "event_hook"
    t.string "event_names"
    t.string "webhook_type"
    t.index ["active"], name: "index_app_events_on_active"
    t.index ["app_id", "event_type"], name: "index_app_events_on_app_id_and_event_type"
    t.index ["app_id"], name: "index_app_events_on_app_id"
  end

  create_table "apps", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "category"
    t.string "service_name", null: false
    t.string "icon_url"
    t.boolean "active", default: true
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "auth_type"
    t.string "side"
    t.string "background_color"
    t.string "webhook_type"
    t.string "image_file_name"
    t.string "image_content_type"
    t.integer "image_file_size"
    t.datetime "image_updated_at"
    t.text "authorization_url"
    t.string "app_client_key"
    t.string "app_secret"
    t.string "provider"
    t.boolean "webhook_enabled", default: false
    t.text "webhook_instructions"
    t.string "status"
    t.string "app_type"
    t.string "category_tags"
    t.index ["active"], name: "index_apps_on_active"
    t.index ["category"], name: "index_apps_on_category"
    t.index ["service_name"], name: "index_apps_on_service_name"
  end

  create_table "konnects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "left_app_id", null: false
    t.integer "right_app_id", null: false
    t.integer "left_app_event_id", null: false
    t.integer "right_app_event_id", null: false
    t.json "config"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_konnects_on_active"
    t.index ["left_app_event_id"], name: "index_konnects_on_left_app_event_id"
    t.index ["left_app_id", "right_app_id"], name: "index_konnects_on_left_app_id_and_right_app_id"
    t.index ["left_app_id"], name: "index_konnects_on_left_app_id"
    t.index ["right_app_event_id"], name: "index_konnects_on_right_app_event_id"
    t.index ["right_app_id"], name: "index_konnects_on_right_app_id"
  end

  add_foreign_key "app_event_configs", "app_events"
  add_foreign_key "app_events", "apps"
  add_foreign_key "konnects", "app_events", column: "left_app_event_id"
  add_foreign_key "konnects", "app_events", column: "right_app_event_id"
  add_foreign_key "konnects", "apps", column: "left_app_id"
  add_foreign_key "konnects", "apps", column: "right_app_id"
end
