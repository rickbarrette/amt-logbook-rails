class AirportUpdate < ApplicationRecord
  scope :in_progress, -> { where(status: %w[pending running]).where(created_at: 2.hours.ago..) }
  def self.latest = order(:created_at).last
end
