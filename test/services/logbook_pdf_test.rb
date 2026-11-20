require "test_helper"

class LogbookPdfTest < ActiveSupport::TestCase
  # Counts the pages the PDF meant to make (the cover, then one per heading)
  # against the pages it ended up with: any extra page is something that
  # overflowed, like the signature lines under a full table of entries.
  class CountingPdf < LogbookPdf
    attr_reader :intended, :total

    def render
      @intended = 1 # the cover has no heading
      out = super
      @total = pdf.page_count
      out
    end

    private

    # Every page after the cover begins with a heading.
    def heading(*)
      @intended += 1
      super
    end
  end

  test "signature lines under a page of entries never spill onto pages of their own" do
    Setting.set("signature_mode", "ink")
    tech = users(:other_tech)
    # Rows of different heights, so the last row lands at every distance from the bottom.
    (1..60).each do |n|
      lines = [ 1, 4, 2, 6, 1, 3, 5, 1, 2 ][n % 9]
      tech.work_entries.create!(performed_on: Date.new(2026, 1, 1) + n, minutes: 120, category: "general", status: "recorded",
                                aircraft: aircraft(:n12345), description: (1..lines).map { "* step #{_1} of the job" }.join("\n"))
      entries = tech.work_entries.includes(:aircraft, :signature).chronological.to_a
      doc = CountingPdf.new(tech, entries, report: ExperienceReport.new(tech))
      doc.render
      assert_equal doc.intended, doc.total, "#{n} entries: #{doc.total - doc.intended} page(s) of overflow"
    end
  end

  test "an unknown supervisor is left blank on the statement page" do
    Setting.set("signature_mode", "ink")
    users(:other_tech).work_entries.create!(performed_on: Date.new(2026, 1, 2), minutes: 60, category: "general", status: "recorded", description: "Washed aircraft")
    assert_nil ExperienceReport.new(users(:other_tech)).signers.first[:name]
  end
end
