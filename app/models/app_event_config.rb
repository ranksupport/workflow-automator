class AppEventConfig < ApplicationRecord
  belongs_to :app_event

  #validates :field_name, presence: true
  #validates :field_type, presence: true

  scope :active, -> { where(active: true) }
  scope :required, -> { where(required: true) }

  FIELD_TYPES = %w[string integer boolean array object].freeze

  validates :field_type, inclusion: { in: FIELD_TYPES }

  def validate_value(value)
    case field_type
    when 'string'
      value.is_a?(String)
    when 'integer'
      value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A\d+\z/))
    when 'boolean'
      [true, false].include?(value) || %w[true false].include?(value.to_s.downcase)
    when 'array'
      value.is_a?(Array)
    when 'object'
      value.is_a?(Hash)
    else
      true
    end
  end
end
