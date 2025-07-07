class AppEvent < ApplicationRecord
  belongs_to :app
  has_many :app_event_configs, dependent: :destroy

  validates :name, presence: true
  validates :event_type, presence: true

  scope :active, -> { where(active: true) }
  scope :triggers, -> { where(event_type: 'trigger') }
  scope :actions, -> { where(event_type: 'action') }

  def config_fields
    app_event_configs.active.pluck(:field_name, :field_type, :required, :description)
  end

  def execute(config = {})
    app.service_instance&.execute_event(self, config)
  end
end
