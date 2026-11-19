# Progress toward the 14 CFR 65.77(b) experience requirement, and statistics,
# for one technician. Only signed entries count toward the requirement (in
# ink-only mode, every finished entry); entries awaiting an electronic
# signature are shown separately as "pending".
class ExperienceReport
  attr_reader :user, :from, :to

  def initialize(user, from: nil, to: nil)
    @user = user
    @from = from
    @to = to
  end

  def entries = @entries ||= user.work_entries.between(from, to).includes(:aircraft, :supervisor, :signature).chronological.to_a
  # "signed" here means counted toward the requirement (see WorkEntry#counted?).
  def signed = @signed ||= entries.select(&:counted?)
  def pending = @pending ||= Setting.ink_signatures? ? [] : entries.select(&:submitted?)

  def rule = Faa.ratings.fetch(user.rating_goal)
  def required_months = rule.fetch("months")
  def hours_per_month = Faa.hours_per_month
  def required_hours = (required_months * hours_per_month).round

  def hours_by_category(list = signed)
    Faa.categories.keys.index_with { |c| hours(list.select { _1.category == c }) }
  end

  def total_hours(list = signed) = hours(list)
  def qualifying_hours(list = signed) = hours(list.select { rule["categories"].include?(_1.category) })
  def pending_qualifying_hours = qualifying_hours(pending)

  # Hours divided by a full-time month (see config/faa/experience_rules.yml).
  def equivalent_months(list = signed) = (qualifying_hours(list) / hours_per_month).round(1)

  def percent_complete = [ (qualifying_hours * 100.0 / required_hours).round, 100 ].min

  # Calendar months spanned by signed experience (first to last entry).
  def calendar_months
    return 0 if signed.empty?
    first, last = signed.first.performed_on, signed.last.performed_on
    ((last.year * 12 + last.month) - (first.year * 12 + first.month) + 1)
  end

  def active_months = signed.map { _1.performed_on.beginning_of_month }.uniq.size

  # For both ratings (65.77(b)(2)): work in each must actually be present.
  def missing_concurrent_categories
    Array(rule["requires_each_of"]).select { |c| signed.none? { _1.category == c } }
  end

  def requirement_met?
    qualifying_hours >= required_hours && calendar_months >= required_months && missing_concurrent_categories.empty?
  end

  # Per-rating progress, so an A&P candidate also sees each side.
  def rating_progress
    Faa.ratings.slice("airframe", "powerplant").transform_values do |r|
      hrs = hours(signed.select { r["categories"].include?(_1.category) })
      req = r["months"] * hours_per_month
      { label: r["label"], hours: hrs, required: req.round, percent: [ (hrs * 100.0 / req).round, 100 ].min }
    end
  end

  # Average hours per week over the last N weeks, and the date the hours
  # requirement would be reached at that pace.
  def recent_weekly_average(weeks = 8)
    since = Date.current - (weeks * 7)
    (hours(signed.select { _1.performed_on > since }) / weeks).round(1)
  end

  def projected_completion
    remaining = required_hours - qualifying_hours
    return Date.current if remaining <= 0
    pace = recent_weekly_average
    pace.positive? ? Date.current + (remaining / pace * 7).ceil : nil
  end

  # { "G-A" => 12.5, ... } hours per ACS subject area (an entry's hours count
  # toward each area it lists).
  def subject_area_hours
    signed.each_with_object(Hash.new(0.0)) do |e, h|
      e.subject_areas.each { h[_1] += e.minutes / 60.0 }
    end.transform_values { _1.round(1) }
  end

  def subject_area_coverage
    covered = subject_area_hours
    Faa.acs_sections.to_h do |key, section|
      areas = section["areas"].keys
      [ key, { label: section["label"], total: areas.size, covered: areas.count { covered[_1].to_f.positive? } } ]
    end
  end

  # Chart series: hours per month by category, over the report period.
  def monthly_series
    months = signed.group_by { _1.performed_on.beginning_of_month }
    Faa.categories.map do |key, label|
      { name: label, data: months.keys.sort.to_h { |m| [ m.strftime("%b %Y"), hours(months[m].select { _1.category == key }) ] } }
    end
  end

  def hours_by_ata = group_hours { _1.ata_label || "Unclassified" }
  def hours_by_aircraft = group_hours { _1.aircraft&.n_number || "No aircraft" }.first(10).to_h
  def hours_by_aircraft_type = group_hours { _1.aircraft&.aircraft_type.presence || _1.aircraft&.description.presence || "Unknown" }
  def hours_by_supervisor = group_hours { _1.supervisor_display_name || "Unknown" }

  # Supervisors of the counted entries, with certificate and period (for the
  # printed book's statement pages).
  def signers
    signed.group_by { [ _1.supervisor_display_name || "Supervisor", _1.supervisor_display_certificate.to_s ] }.map do |(name, cert), list|
      { name:, certificate: cert.presence || "__________", from: list.first.performed_on, to: list.last.performed_on,
        hours: hours(list), by_category: hours_by_category(list) }
    end
  end

  private

  def hours(list) = (list.sum(&:minutes) / 60.0).round(1)

  def group_hours(&key)
    signed.group_by(&key).transform_values { hours(_1) }.sort_by { -_2 }.to_h
  end
end
