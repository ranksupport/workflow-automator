require 'logger'
require 'sinatra/activerecord/rake'
require './app'

task :environment do
  require './app'
end

namespace :db do
  task :create_migration do
    name = ARGV[1] || raise("Specify name: rake db:create_migration your_migration")
    timestamp = Time.now.strftime("%Y%m%d%H%M%S") 
    path = File.expand_path("db/migrate/#{timestamp}_#{name}.rb", __FILE__)
    migration_class = name.split("_").map(&:capitalize).join

    File.open(path, 'w') do |file|
      file.write <<-EOF
class #{migration_class} < ActiveRecord::Migration[7.0]
  def up
  end

  def down
  end
end
EOF
    end

    puts "Created migration: #{path}"
  end
end