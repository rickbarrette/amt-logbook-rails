require "test_helper"

# The keyword file is hand-edited; catch mistakes in it before they turn
# into odd suggestions.
class EntrySuggesterRulesTest < ActiveSupport::TestCase
  RULES = YAML.load_file(Rails.root.join("config/faa/suggestions.yml"))
  ACS_CODES = Faa.acs_sections.values.flat_map { _1["areas"].keys }.to_set

  test "every chapter has a known ATA label, category and ACS areas" do
    RULES["chapters"].each do |chapter, info|
      assert Faa.ata_chapters.key?(chapter), "chapter #{chapter} isn't in ata_chapters.yml"
      assert Faa.categories.key?(info["category"]), "chapter #{chapter}: unknown category #{info["category"]}"
      Array(info["areas"]).each { assert_includes ACS_CODES, _1, "chapter #{chapter}: unknown ACS area #{_1}" }
      areas = Array(info["areas"]).map { Faa.subject_area_section(_1) }.uniq - [ "general" ]
      assert areas.all? { _1 == info["category"] }, "chapter #{chapter}: its areas belong to #{areas}, not #{info["category"]}"
    end
  end

  test "every keyword is a string pointing at a configured chapter, with a positive weight and real ACS areas" do
    RULES["keywords"].each do |word, (chapter, weight, areas)|
      assert_kind_of String, word, "#{word.inspect} isn't a string (quote it in the YAML)"
      assert RULES["chapters"].key?(chapter.to_s), "#{word}: chapter #{chapter.inspect} has no defaults"
      assert_operator weight.to_f, :>, 0, "#{word}: weight must be positive"
      Array(areas).each { assert_includes ACS_CODES, _1, "#{word}: unknown ACS area #{_1}" }
    end
  end

  test "no two keywords match the same thing" do
    patterns = EntrySuggester.keywords.map { _1.first.source }
    dupes = patterns.tally.select { _2 > 1 }.keys
    assert_empty dupes, "keywords that duplicate each other: #{dupes.join(", ")}"
  end

  test "keywords are lowercase so they read consistently" do
    upper = RULES["keywords"].keys.map(&:to_s).grep(/[A-Z]/)
    assert_empty upper, "use lowercase (matching ignores case): #{upper.join(", ")}"
  end

  test "wildcards don't swallow unrelated everyday words" do
    { "toward" => "09", "washer" => "12", "jacket" => "07", "seated" => "25", "lightly" => "33",
      "retracted flaps" => "32", "identified" => "51", "address" => "61", "event" => "21",
      "lighten" => "33", "seating" => "25", "dipstick" => "27" }.each do |text, wrong|
      s = EntrySuggester.new.suggest("#{text} xx")
      assert_not_equal wrong, s&.ata_chapter, "#{text.inspect} shouldn't suggest ATA #{wrong}"
    end
  end
end
