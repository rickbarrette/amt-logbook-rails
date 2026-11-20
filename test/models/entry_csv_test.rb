require "test_helper"

class EntryCsvTest < ActiveSupport::TestCase
  test "dates in the formats people type" do
    assert_equal Date.new(2026, 3, 4), EntryCsv.parse_date("2026-03-04")
    assert_equal Date.new(2026, 3, 4), EntryCsv.parse_date("3/4/2026")
    assert_equal Date.new(2026, 3, 4), EntryCsv.parse_date("03/04/26")
    assert_equal Date.new(2026, 4, 3), EntryCsv.parse_date("3/4/2026", "dmy")
    assert_equal Date.new(2026, 11, 12), EntryCsv.parse_date("Nov 12, 2026")
    assert_equal Date.new(2026, 11, 12), EntryCsv.parse_date("2026-11-12T08:00:00Z")
    assert_nil EntryCsv.parse_date("13/45/2026")
    assert_nil EntryCsv.parse_date("soon")
    assert_nil EntryCsv.parse_date("")
  end

  test "hours as decimals, h:mm, with units or a decimal comma" do
    assert_in_delta 1.5, EntryCsv.parse_hours("1.5")
    assert_in_delta 1.5, EntryCsv.parse_hours("1,5")
    assert_in_delta 1.5, EntryCsv.parse_hours("1:30")
    assert_in_delta 2.0, EntryCsv.parse_hours("2 hrs")
    assert_in_delta 1.5, EntryCsv.parse_hours("90 min")
    assert_nil EntryCsv.parse_hours("")
    assert_nil EntryCsv.parse_hours("lots")
  end

  test "categories, ATA chapters and ACS areas" do
    assert_equal "airframe", EntryCsv.parse_category("Airframe")
    assert_equal "airframe", EntryCsv.parse_category("A")
    assert_equal "powerplant", EntryCsv.parse_category("P")
    assert_equal "powerplant", EntryCsv.parse_category("Power plant")
    assert_equal "general", EntryCsv.parse_category("Gen")
    assert_nil EntryCsv.parse_category("A&P")
    assert_nil EntryCsv.parse_category("misc")
    assert_equal "32", EntryCsv.parse_ata("32 Landing Gear")
    assert_equal "05", EntryCsv.parse_ata("ATA 5")
    assert_nil EntryCsv.parse_ata("99")
    assert_equal %w[A-II-A G-K], EntryCsv.parse_subject_areas("a-ii-a G-K X-Y-Z")
    assert_equal %w[A-II-A G-K], EntryCsv.parse_subject_areas("Landing Gear Systems; Inspection Concepts and Techniques")
  end

  test "reads this app's own CSV export and matches every column" do
    entries = users(:tech).work_entries.includes(:aircraft, :signature, :supervisor)
    csv = EntryCsv.new(LogbookCsv.new(entries).to_csv)
    mapping = csv.guess_mapping
    assert_equal csv.headers.index("Date"), mapping["performed_on"]
    assert_equal csv.headers.index("N-number"), mapping["n_number"]
    assert_equal csv.headers.index("Description"), mapping["description"]
    assert_equal csv.headers.index("ACS subject areas"), mapping["subject_areas"]
    assert_equal csv.headers.index("Certificate"), mapping["supervisor_certificate"]
  end

  test "semicolons, a byte-order mark and Windows encoding" do
    csv = EntryCsv.new("﻿Date;Hours;Work performed\n2026-01-02;1,5;Safety wired\n")
    assert_equal [ "Date", "Hours", "Work performed" ], csv.headers
    assert_equal({ "performed_on" => 0, "hours" => 1, "description" => 2 }, csv.guess_mapping)
    latin = "Date,Hours,Description\n2026-01-02,1,Replaced caf\xE9 seat\n".b
    assert_equal "Replaced café seat", EntryCsv.new(latin).rows.first[2]
  end

  test "formula guards from our export are removed" do
    assert_equal "-1 lead", EntryCsv.unescape("'-1 lead")
    assert_equal "'quoted'", EntryCsv.unescape("'quoted'")
  end

  test "refuses empty files and too many rows" do
    assert_raises(EntryCsv::Error) { EntryCsv.new("") }
    big = "Date,Hours,Description\n" + ("2026-01-01,1,x\n" * (EntryCsv::MAX_ROWS + 1))
    assert_raises(EntryCsv::Error) { EntryCsv.new(big) }
  end
end
