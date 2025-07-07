class ApiKey < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }

  before_create :generate_key

  def self.create_key(name, description = nil)
    create!(
      name: name,
      description: description,
      active: true
    )
  end

  def deactivate!
    update!(active: false)
  end

  def activate!
    update!(active: true)
  end

  private

  def generate_key
    self.key = SecureRandom.hex(32) if key.blank?
  end
end
