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

  # Clocks in and opens the draft entry for this work, so it can be filled in
  # while the clock runs; clocking out sets its hours.
  def self.start!(user:, **attrs)
    transaction do
      user.timers.running.each(&:pause!) # one running clock at a time
      now = Time.current
      timer = user.timers.create!(attrs.merge(started_at: now, running_since: now))
      timer.update!(work_entry: user.work_entries.create!(timer.entry_attributes(now)))
      timer
    end
  end

  def entry_attributes(now = Time.current)
    { aircraft:, performed_on: started_at.in_time_zone(user.time_zone.presence || Time.zone).to_date, started_at:,
      minutes: rounded_minutes(elapsed_seconds(now)), category: category.presence || "general",
      description: description.presence || "(describe the work)",
      supervisor: user.supervisors.one? ? user.supervisors.first : nil }
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

  # Stops the clock and sets the entry's hours (rounded to 0.1 hour, at
  # least 6 minutes). What was typed into the entry meanwhile is kept.
  def stop!
    transaction do
      now = Time.current
      seconds = elapsed_seconds(now)
      update!(accumulated_seconds: seconds, running_since: nil, stopped_at: now)
      minutes = rounded_minutes(seconds)
      entry = work_entry&.editable? ? work_entry : nil
      if entry
        entry.update!(minutes:, started_at:, ended_at: now)
      else # started before entries opened at clock-in, or the entry was deleted
        entry = user.work_entries.create!(entry_attributes(now).merge(minutes:, ended_at: now))
        update!(work_entry: entry)
      end
      entry
    end
  end

  # Throws away the clock and its entry if that's still an untouched draft.
  def discard!
    transaction do
      entry = work_entry
      destroy!
      entry.destroy! if entry&.draft?
    end
  end

  private

  def rounded_minutes(seconds) = [ [ ((seconds / 360.0).round * 6), 6 ].max, WorkEntry::MAX_MINUTES ].min
end
