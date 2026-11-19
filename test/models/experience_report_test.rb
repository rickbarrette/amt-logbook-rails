require "test_helper"

class ExperienceReportTest < ActiveSupport::TestCase
  setup do
    @tech = users(:tech)
    @tech.work_entries.delete_all
  end

  # Adds the hours as entries of at most 10 hours each, on the given day.
  def add(category, hours, on:, signed: true)
    minutes = (hours * 60).round
    entries = []
    while minutes.positive?
      chunk = [ minutes, 600 ].min
      e = @tech.work_entries.create!(category:, minutes: chunk, performed_on: on, description: "work", supervisor: users(:sup))
      e.submit!
      EntrySignature.sign!(e, by: users(:sup), certificate: user_certificates(:sup_ap)) if signed
      entries << e
      minutes -= chunk
    end
    entries.last
  end

  test "both ratings: 30 months at 160 h, airframe and powerplant both required" do
    add("airframe", 100, on: Date.new(2026, 1, 10))
    add("general", 60, on: Date.new(2026, 3, 10))
    add("airframe", 8, on: Date.new(2026, 3, 11), signed: false)
    r = ExperienceReport.new(@tech)
    assert_equal 30, r.required_months
    assert_equal 4800, r.required_hours
    assert_equal 160.0, r.qualifying_hours
    assert_equal 1.0, r.equivalent_months
    assert_equal 3, r.calendar_months
    assert_equal 8.0, r.pending_qualifying_hours
    assert_equal [ "powerplant" ], r.missing_concurrent_categories
    assert_not r.requirement_met?
  end

  test "airframe only counts airframe and general work" do
    @tech.update!(rating_goal: "airframe")
    add("airframe", 10, on: Date.current - 10)
    add("powerplant", 10, on: Date.current - 9)
    add("general", 5, on: Date.current - 8)
    r = ExperienceReport.new(@tech)
    assert_equal 18, r.required_months
    assert_equal 2880, r.required_hours
    assert_equal 15.0, r.qualifying_hours
    assert_equal({ "airframe" => 10.0, "powerplant" => 10.0, "general" => 5.0 }, r.hours_by_category)
  end

  test "requirement met when hours, months and both kinds of work are present" do
    @tech.update!(rating_goal: "airframe")
    start = Date.new(2024, 1, 1)
    18.times { |i| add("airframe", 160, on: start >> i) }
    assert ExperienceReport.new(@tech).requirement_met?
  end

  test "subject area hours and coverage" do
    e = add("airframe", 2, on: Date.current - 1, signed: false)
    e.update!(subject_areas: %w[A-II-A G-C])
    EntrySignature.sign!(e, by: users(:sup), certificate: user_certificates(:sup_ap))
    r = ExperienceReport.new(@tech)
    assert_equal({ "A-II-A" => 2.0, "G-C" => 2.0 }, r.subject_area_hours)
    assert_equal 1, r.subject_area_coverage["airframe"][:covered]
    assert_equal 15, r.subject_area_coverage["airframe"][:total]
  end

  test "signers summary for the supervisor statement pages" do
    add("airframe", 4, on: Date.new(2026, 2, 1))
    add("powerplant", 6, on: Date.new(2026, 4, 1))
    s = ExperienceReport.new(@tech).signers.sole
    assert_equal "Sam Supervisor", s[:name]
    assert_equal 10.0, s[:hours]
    assert_equal Date.new(2026, 2, 1), s[:from]
  end
end
