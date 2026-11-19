# A clock-in timer kept on the server: closing the app or switching devices
# doesn't stop it. Time is started_at/running_since stamps plus seconds
# accumulated across pauses, so nothing has to tick.
class Timer < ApplicationRecord
  belongs_to :user
  belongs_to :aircraft, optional: true
  belongs_to :work_entry, optional: true

  scope :active, -> { where(stopped_at: nil) }
  scope :running, -> { active.where.not(running_since: nil) }

  validates :category, inclusion: { in: ->(_) { Faa.categories.keys } }, allow_blank: true
  validates :description, length: { maximum: 500 }

  def self.start!(user:, **attrs)
    transaction do
      user.timers.running.each(&:pause!) # one running clock at a time
      now = Time.current
      user.timers.create!(attrs.merge(started_at: now, running_since: now))
    end
  end

  def running? = running_since.present? && stopped_at.nil?
  def paused? = running_since.nil? && stopped_at.nil?
  def stopped? = stopped_at.present?

  def elapsed_seconds(at = Time.current)
    accumulated_seconds + (running_since ? (at - running_since).to_i : 0)
  end

  def pause!
    return unless running?
    update!(accumulated_seconds: elapsed_seconds, running_since: nil)
  end

  def resume!
    return unless paused?
    transaction do
      user.timers.running.where.not(id: id).each(&:pause!)
      update!(running_since: Time.current)
    end
  end

  # Stops the clock and turns it into a draft entry (rounded to 0.1 hour, min 6 min).
  def stop!
    transaction do
      now = Time.current
      seconds = elapsed_seconds(now)
      update!(accumulated_seconds: seconds, running_since: nil, stopped_at: now)
      minutes = [ ((seconds / 360.0).round * 6), 6 ].max
      entry = user.work_entries.create!(
        aircraft:, performed_on: started_at.in_time_zone(user.time_zone || Time.zone).to_date,
        started_at:, ended_at: now, minutes: [ minutes, WorkEntry::MAX_MINUTES ].min,
        category: category.presence || "general", description: description.presence || "(describe the work)",
        supervisor: user.supervisors.one? ? user.supervisors.first : nil
      )
      update!(work_entry: entry)
      entry
    end
  end
end
