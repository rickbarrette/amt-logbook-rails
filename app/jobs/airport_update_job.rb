# Downloads OurAirports and syncs the airports table.
class AirportUpdateJob < ApplicationJob
  queue_as :default

  def perform(update_id = nil)
    update = (update_id && AirportUpdate.find_by(id: update_id)) || AirportUpdate.create!
    update.update!(status: "running", started_at: Time.current, error: nil)
    counts = AirportData.refresh!
    update.update!(status: "done", finished_at: Time.current, created_count: counts[:created],
                   updated_count: counts[:updated], removed_count: counts[:removed])
  rescue StandardError => e
    update&.update!(status: "failed", finished_at: Time.current, error: "#{e.class}: #{e.message}".truncate(1000))
    Rails.logger.error("[airports] update failed: #{e.class}: #{e.message}")
  end

  # At boot: populate the table on first start.
  def self.ensure_populated
    return if Airport.exists? || AirportUpdate.in_progress.exists?
    perform_later(AirportUpdate.create!.id)
  end
end
