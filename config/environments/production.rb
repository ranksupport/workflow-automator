require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.log_level = :info
  config.log_tags = [ :request_id ]
  config.cache_store = :memory_store
  config.active_job.queue_adapter = :async
  config.active_support.deprecation = :notify
  config.active_support.disallowed_deprecation = :log
  config.active_support.disallowed_deprecation_warnings = []
  config.active_record.dump_schema_after_migration = false

  config.hosts << ENV.fetch('ALLOWED_HOSTS', '').split(',')
end
