require "test_helper"

class EntrySuggesterTest < ActiveSupport::TestCase
  def suggest(text, user: nil) = EntrySuggester.new(user:).suggest(text)

  test "sheet metal work is airframe structures" do
    s = suggest("* replaced loose oil door hinge rivets\n* installed new skin rivets at inboard flap track left side\n* serviced & dressed flap tracks")
    assert_equal "airframe", s.category
    assert_includes %w[51 57], s.ata_chapter
    assert_includes s.subject_areas, "A-I-A"
  end

  test "engine work is powerplant" do
    s = suggest("Removed, cleaned and gapped spark plugs; magneto timing check")
    assert_equal "powerplant", s.category
    assert_equal "74", s.ata_chapter
    assert_includes s.subject_areas, "P-II-E"
  end

  test "oil change" do
    s = suggest("Oil change, cut filter for inspection, safety wired")
    assert_equal "79", s.ata_chapter
    assert_equal "powerplant", s.category
  end

  test "weighing is general" do
    s = suggest("Weighed aircraft and computed new empty weight and CG")
    assert_equal "08", s.ata_chapter
    assert_equal "general", s.category
    assert_includes s.subject_areas, "G-C"
  end

  test "nothing recognizable" do
    assert_nil suggest("xyzzy plugh")
    assert_nil suggest("ok")
  end

  test "keywords match whole words only" do
    s = suggest("Adjusted the trim tab")
    assert_equal "27", s.ata_chapter
    assert_nil suggest("tripod stuff") # "trip" isn't "trim", "pod" isn't anything
  end

  test "many past entries sharing one word don't outvote the keywords" do
    user = users(:tech)
    5.times { |i| user.work_entries.create!(performed_on: Date.current - i - 5, minutes: 60, category: "powerplant", ata_chapter: "79", description: "Changed oil and filter, cut filter") }
    s = suggest("replaced loose oil door hinge rivets\ninstalled new skin rivets at inboard flap track left side", user:)
    assert_equal "airframe", s.category
    assert_equal "51", s.ata_chapter
    assert_not_includes s.subject_areas, "P-II-D", "no powerplant areas on an airframe entry"
  end

  test "the technician's past entries vote" do
    user = users(:tech)
    user.work_entries.create!(performed_on: Date.current - 9, minutes: 60, category: "airframe", ata_chapter: "38",
                              description: "Flushed the galley tank and replaced the faucet cartridge")
    s = suggest("Replaced galley faucet cartridge and flushed tank", user:)
    assert_equal "38", s.ata_chapter
  end
end
