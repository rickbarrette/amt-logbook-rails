require "test_helper"

class EntryImportTest < ActiveSupport::TestCase
  CSV_DATA = <<~CSV.freeze
    Date,Tail,Hrs,Work performed,Type,ATA,Supervised by,Cert
    11/03/2026,N12345,1.5,Replaced left main brake linings,Airframe,32,Pat Mechanic,A&P 1234567
    11/04/2026,N12345,2:00,Changed oil and filter,,,Pat Mechanic,A&P 1234567
    11/05/2026,C-GABC,1,Timed magnetos,P,74,,
    not a date,N12345,1,Nothing,,,,
    11/06/2026,,30,Too long,,,,
  CSV

  def csv_import(user = users(:tech), data = CSV_DATA)
    import = user.entry_imports.new(kind: "csv", filename: "old.csv", data:)
    import.mapping = import.csv.guess_mapping
    import.save!
    import
  end

  test "guesses the columns of a typical spreadsheet" do
    m = csv_import.mapping
    assert_equal({ "performed_on" => 0, "n_number" => 1, "hours" => 2, "description" => 3, "category" => 4,
                   "ata_chapter" => 5, "supervisor_name" => 6, "supervisor_certificate" => 7 }, m)
  end

  test "imports readable rows as drafts, suggests what's missing, reports the rest" do
    import = csv_import
    assert_difference -> { users(:tech).work_entries.count }, 3 do
      import.run!
    end
    assert import.done?
    assert_equal [ 3, 2 ], [ import.created_count, import.skipped_count ]
    assert_match(/Row 5: no date/, import.problems.join)
    assert_match(/Row 6: 30.0 hours/, import.problems.join)

    brakes, oil, mags = import.work_entries.order(:performed_on).to_a
    assert brakes.draft?
    assert_equal [ Date.new(2026, 11, 3), 90, "airframe", "32", "N12345" ], [ brakes.performed_on, brakes.minutes, brakes.category, brakes.ata_chapter, brakes.aircraft.n_number ]
    assert_equal [ "Pat Mechanic", "A&P 1234567" ], [ brakes.supervisor_name, brakes.supervisor_certificate ]
    assert_equal [ "79", "powerplant" ], [ oil.ata_chapter, oil.category ], "missing category and chapter are suggested"
    assert_equal %w[category ata_chapter subject_areas], oil.import_details["suggested"]
    assert_nil mags.aircraft, "a non-US registration isn't linked"
    assert_equal "C-GABC", mags.import_details["aircraft"]
    assert_equal "-", import.reload.data, "the uploaded file isn't kept"
  end

  test "importing the same file again adds nothing" do
    csv_import.run!
    again = csv_import
    assert_no_difference(-> { WorkEntry.count }) { again.run! }
    assert_match(/already in your logbook/, again.problems.join)
  end

  test "undo removes only untouched drafts" do
    import = csv_import
    import.run!
    kept = import.work_entries.order(:performed_on).first
    kept.record!
    assert_equal 2, import.undo!
    assert_equal [ kept ], import.work_entries.reload.to_a
    assert_equal 1, import.reload.created_count
  end

  test "day/month dates when asked" do
    import = csv_import(users(:tech), "Date,Hours,Description\n03/04/2026,1,Lubed hinges\n")
    import.update!(options: { "date_format" => "dmy" })
    import.run!
    assert_equal Date.new(2026, 4, 3), import.work_entries.first.performed_on
  end

  test "a full export imports into another logbook, signatures kept as history" do
    signed = signed_entry
    json = LogbookExport.new(users(:tech)).to_json
    doc = JSON.parse(json)
    assert_equal "amt-logbook-export", doc["format"]
    assert doc["entries"].find { _1["signature"] }.dig("signature", "intact")

    import = users(:other_tech).entry_imports.create!(kind: "json", filename: "jane.json", data: json)
    import.run!
    assert_equal users(:tech).work_entries.count, import.created_count
    copy = import.work_entries.find_by(description: signed.description)
    assert copy.draft?, "signatures don't move between servers"
    assert_equal [ signed.minutes, signed.category, signed.ata_chapter, signed.aircraft.n_number ], [ copy.minutes, copy.category, copy.ata_chapter, copy.aircraft.n_number ]
    assert_equal "Sam Supervisor", copy.supervisor_name
    assert_equal "signed", copy.import_details["original_status"]
    assert_equal "Sam Supervisor", copy.import_details.dig("signature", "signer_name")
  end

  test "rejects JSON that isn't an export" do
    import = users(:tech).entry_imports.new(kind: "json", data: '{"hello": 1}')
    assert_raises(EntryCsv::Error) { import.preview }
    assert_raises(EntryCsv::Error) { users(:tech).entry_imports.new(kind: "json", data: "{nope").preview }
  end
end
