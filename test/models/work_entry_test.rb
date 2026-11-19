require "test_helper"

class WorkEntryTest < ActiveSupport::TestCase
  test "hours are stored as minutes" do
    e = WorkEntry.new(hours: "2.5")
    assert_equal 150, e.minutes
    assert_equal 2.5, e.hours
  end

  test "requires known category, ATA chapter and subject areas" do
    e = work_entries(:draft)
    e.category = "avionics"
    e.ata_chapter = "99"
    e.subject_areas = [ "ZZZ" ]
    assert_not e.valid?
    assert e.errors[:category].any?
    assert e.errors[:ata_chapter].any?
    assert e.errors[:subject_areas].any?
  end

  test "rejects future dates and over 24 hours" do
    e = work_entries(:draft)
    e.performed_on = Date.current + 5
    e.minutes = 25 * 60
    assert_not e.valid?
    assert e.errors[:performed_on].any?
    assert e.errors[:minutes].any?
  end

  test "supervisor must be linked to the technician" do
    e = work_entries(:tom_entry)
    e.supervisor = users(:sup)
    assert_not e.valid?
    assert_includes e.errors[:supervisor].join, "isn't one of your supervisors"
  end

  test "signed entries can't be changed or deleted" do
    entry = signed_entry
    assert entry.signed?
    assert_not entry.update(description: "changed")
    assert_equal "Oil change and filter inspection, safety wired filter.", entry.reload.description
    assert_not entry.destroy
    assert WorkEntry.exists?(entry.id)
  end

  test "submit and return" do
    e = work_entries(:draft)
    e.submit!
    assert e.submitted?
    e.return!("Add the manual reference")
    assert e.returned?
    assert e.editable?
    assert_equal "Add the manual reference", e.returned_reason
  end
end
