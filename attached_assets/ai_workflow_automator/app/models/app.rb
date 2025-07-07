require 'logger'

require 'sinatra'
require 'sinatra/activerecord'
require './models/your_model_file' # if applicable

get '/' do
  "Hello from Sinatra!"
end


class App < ApplicationRecord
  has_many :app_events, dependent: :destroy
  has_many :konnects, dependent: :destroy

  validates :name, presence: true
  validates :service_name, presence: true

  scope :active, -> { where(active: true) }

  def service_class
    "#{service_name.classify}".constantize
  rescue NameError
    nil
  end

  def service_instance
    service_class&.new
  end

  def available_actions
    service_instance&.available_actions || []
  end
end
