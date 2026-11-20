require "test_helper"

class BulkActionsTest < ActionDispatch::IntegrationTest
  setup do
    @tech = users(:tech)
    sign_in_as @tech
  end

  def draft(**attrs)
    @tech.work_entries.create!({ performed_on: Date.current - 4, minutes: 60, category: "general", description: "Washed aircraft" }.merge(attrs))
  end

  def bulk(action, entries, **params)
    post bulk_work_entries_path, params: { bulk_action: action, entry_ids: entries.map(&:id), return_to: "/work_entries" }.merge(params)
  end

  test "the list has checkboxes and the action bar" do
    get work_entries_path
    assert_select "#bulk-form select[name=bulk_action] option[value=submit]"
    assert_select "input[type=checkbox][name='entry_ids[]'][form=bulk-form]", minimum: 1
  end

  test "send several for signature; signed and waiting ones are skipped" do
    a, b = draft, draft(description: "Lubed hinges")
    signed = signed_entry
    bulk("submit", [ a, b, signed ], supervisor_id: users(:sup).id)
    assert_redirected_to "/work_entries"
    assert_equal %w[submitted submitted], [ a.reload.status, b.reload.status ]
    assert signed.reload.signed?
    assert_equal "Sent 2 entries. Skipped 1: 1 signed.", flash[:notice]
  end

  test "sending needs a supervisor of yours" do
    a = draft
    bulk("submit", [ a ], supervisor_id: users(:admin).id)
    assert a.reload.draft?
    assert_match(/no supervisor chosen/, flash[:alert])
  end

  test "ink mode: set the supervisor on all, then record them; a running timer is skipped" do
    Setting.set("signature_mode", "ink")
    a, b = draft, draft(description: "Lubed hinges")
    clocking = Timer.start!(user: @tech).work_entry
    bulk("supervisor", [ a, b ], supervisor_name: "Pat Mechanic", supervisor_certificate: "A&P 1234567")
    assert_equal [ "Pat Mechanic", "A&P 1234567" ], [ a.reload.supervisor_name, b.reload.supervisor_certificate ]
    bulk("record", [ a, b, clocking ])
    assert_equal %w[recorded recorded draft], [ a.reload.status, b.reload.status, clocking.reload.status ]
    assert_match(/Skipped 1: 1 timer still running/, flash[:notice])
  end

  test "edit fields: only what's filled in changes, ACS areas are added" do
    a = draft(category: "airframe", ata_chapter: "32", subject_areas: [ "A-II-A" ], location: "KPVD")
    b = draft(category: "general")
    bulk("fields", [ a, b ], ata_chapter: "05", add_subject_area: [ "G-K" ], category: "", location: "")
    a.reload
    b.reload
    assert_equal [ "airframe", "05", %w[A-II-A G-K], "KPVD" ], [ a.category, a.ata_chapter, a.subject_areas, a.location ]
    assert_equal [ "general", "05", %w[G-K] ], [ b.category, b.ata_chapter, b.subject_areas ]

    bulk("fields", [ a ])
    assert_match(/nothing to change/, flash[:alert])
  end

  test "delete removes drafts but never signed entries or other people's" do
    a = draft
    signed = signed_entry
    toms = users(:other_tech).work_entries.create!(performed_on: Date.current - 2, minutes: 60, category: "general", description: "Tom's")
    assert_difference -> { WorkEntry.count }, -1 do
      bulk("delete", [ a, signed, toms ])
    end
    assert WorkEntry.exists?(signed.id)
    assert WorkEntry.exists?(toms.id)
  end

  test "export the selected entries as CSV or PDF" do
    a = draft(description: "Only this one")
    draft(description: "Not this one")
    bulk("export_csv", [ a ])
    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body, headers: true)
    assert_equal [ "Only this one" ], rows.map { _1["Description"] }

    signed = signed_entry
    bulk("export_pdf", [ signed ])
    assert_equal "application/pdf", response.media_type
    bulk("export_pdf", [ a ])
    assert_match(/can be printed yet/, flash[:alert])
  end

  test "a supervisor can export a technician's selected entries but not change them" do
    enable_2fa(users(:sup))
    sign_in_as users(:sup)
    signed = signed_entry
    post bulk_work_entries_path, params: { bulk_action: "export_csv", entry_ids: [ signed.id ], technician_id: @tech.id }
    assert_equal "text/csv", response.media_type
    a = draft
    post bulk_work_entries_path, params: { bulk_action: "delete", entry_ids: [ a.id ], technician_id: @tech.id }
    assert WorkEntry.exists?(a.id), "only your own entries change"
  end

  test "nothing ticked" do
    post bulk_work_entries_path, params: { bulk_action: "delete" }
    assert_match(/Tick at least one/, flash[:alert])
  end
end
