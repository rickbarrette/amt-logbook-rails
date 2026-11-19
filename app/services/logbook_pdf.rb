require "prawn"
require "prawn/table"

# The printable experience logbook: cover with the technician's statement,
# summary against 14 CFR 65.77, a statement page for each supervisor to sign,
# then the entries with page totals, totals brought forward, and a column for
# the supervisor's ink signature next to the recorded electronic one.
class LogbookPdf
  include ActionView::Helpers::NumberHelper

  MARGIN = 36
  DARK = "1F2937"
  MUTED = "6B7280"
  RULE = "9CA3AF"
  FILL = "F3F4F6"

  def initialize(technician, entries, report:, from: nil, to: nil, ink: Setting.ink_signatures?)
    @ink = ink
    @tech = technician
    @entries = entries
    @report = report
    @from = from
    @to = to
  end

  def render
    @pdf = Prawn::Document.new(page_size: "LETTER", page_layout: :landscape, margin: MARGIN,
                               info: { Title: "AMT Experience Logbook - #{@tech.name}", Creator: "AMT Logbook" })
    @pdf.font "Helvetica"
    @pdf.default_leading 1
    cover
    summary
    supervisor_statements
    entry_pages
    footer
    @pdf.render
  end

  private

  attr_reader :pdf

  def txt(s) = s.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
  def hrs(minutes) = number_with_precision(minutes / 60.0, precision: 1)
  def period
    first = @from || @entries.first&.performed_on
    last = @to || @entries.last&.performed_on
    first ? "#{first.strftime("%b %-d, %Y")} - #{(last || Date.current).strftime("%b %-d, %Y")}" : "No entries"
  end

  def heading(title, sub = nil)
    pdf.fill_color DARK
    pdf.text txt(title), size: 16, style: :bold
    pdf.fill_color MUTED
    pdf.text(txt(sub), size: 9) if sub
    pdf.fill_color DARK
    pdf.move_down 10
  end

  def signature_line(label, width: 220)
    pdf.move_down 26
    y = pdf.cursor
    pdf.stroke_color RULE
    pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.left + width, at: y
    pdf.move_down 3
    pdf.text txt(label), size: 8, color: MUTED
  end

  def cover
    pdf.move_down 90
    pdf.text "AVIATION MAINTENANCE TECHNICIAN", size: 12, style: :bold, color: MUTED, align: :center, character_spacing: 2
    pdf.text "Practical Experience Logbook", size: 30, style: :bold, align: :center
    pdf.move_down 6
    pdf.text "Documentary evidence of practical experience - 14 CFR 65.77(b)", size: 11, color: MUTED, align: :center
    pdf.move_down 40
    rows = [ [ "Technician", @tech.name ], [ "Rating sought", @tech.rating_goal_label ], [ "Period", period ],
             [ "Entries", @entries.size.to_s ], [ "Printed", Date.current.strftime("%B %-d, %Y") ] ]
    pdf.table(rows.map { |a, b| [ txt(a), txt(b) ] }, position: :center, column_widths: [ 140, 300 ],
              cell_style: { borders: [ :bottom ], border_color: "E5E7EB", size: 11, padding: [ 6, 8 ] }) do |t|
      t.column(0).font_style = :bold
      t.column(0).text_color = MUTED
    end
    pdf.move_down 50
    pdf.bounding_box([ pdf.bounds.width / 2 - 220, pdf.cursor ], width: 440) do
      pdf.text txt("Technician's statement: I certify that the experience recorded in this logbook is true and correct, " \
                   "and was performed by me under the supervision of the persons who signed each entry."), size: 9
      signature_line("Technician signature", width: 260)
      pdf.move_up 37
      pdf.indent(290) { signature_line("Date", width: 150) }
    end
  end

  def summary
    pdf.start_new_page
    heading("Experience summary", "#{@ink ? "Recorded entries, signed in ink on the pages that follow" : "Signed entries only"}. Equivalent months = qualifying hours / #{@report.hours_per_month.round} hours " \
            "(a full-time month). The FAA inspector makes the final determination.")
    r = @report
    cats = r.hours_by_category
    rows = [ [ "Rating sought", @tech.rating_goal_label ],
             [ "Requirement", "#{r.required_months} months (#{"14 CFR 65.77(b)(#{@tech.rating_goal == "both" ? 2 : 1})"})" ],
             [ "Airframe hours", cats["airframe"].to_s ], [ "Powerplant hours", cats["powerplant"].to_s ],
             [ "General hours", cats["general"].to_s ], [ "Total signed hours", r.total_hours.to_s ],
             [ "Qualifying hours", "#{r.qualifying_hours} of #{r.required_hours} (#{r.percent_complete}%)" ],
             [ "Equivalent months", "#{r.equivalent_months} of #{r.required_months}" ],
             [ "Calendar months covered", r.calendar_months.to_s ], [ "Months with experience", r.active_months.to_s ] ]
    pdf.table(rows.map { |a, b| [ txt(a), txt(b) ] }, column_widths: [ 160, 240 ],
              cell_style: { size: 9, padding: [ 4, 6 ], border_color: "E5E7EB" }) { |t| t.column(0).background_color = FILL }
    acs_coverage
  end

  # The ACS subject areas side by side (General | Airframe | Powerplant), with hours.
  def acs_coverage
    pdf.move_down 16
    pdf.text "ACS subject areas (FAA-S-ACS-1): hours of signed experience", size: 10, style: :bold
    pdf.move_down 4
    hours = @report.subject_area_hours
    sections = Faa.acs_sections.values
    cells = ->(code, label) { h = hours[code]; [ txt("#{h ? "[x]" : "[ ]"} #{label}"), h ? h.to_s : "" ] }
    rows = (0...sections.map { _1["areas"].size }.max).map do |i|
      sections.flat_map { |sec| (pair = sec["areas"].to_a[i]) ? cells.(*pair) : [ "", "" ] }
    end
    header = sections.flat_map { [ txt(_1["label"]), "Hours" ] }
    pdf.table([ header ] + rows, width: pdf.bounds.width, header: true,
              column_widths: { 1 => 34, 3 => 34, 5 => 34 },
              cell_style: { size: 7, padding: [ 2, 4 ], borders: [ :bottom ], border_color: "E5E7EB" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = FILL
      t.columns([ 1, 3, 5 ]).align = :right
    end
  end

  def supervisor_statements
    @report.signers.each do |s|
      pdf.start_new_page
      heading("Supervisor's statement of experience", "For the FAA inspector, with FAA Form 8610-2.")
      c = s[:by_category]
      pdf.text txt("I, #{s[:name]}, holder of certificate #{s[:certificate]}, certify that #{@tech.name} performed practical " \
                   "experience in the construction, maintenance, or alteration of aircraft under my supervision from " \
                   "#{s[:from].strftime("%B %-d, %Y")} to #{s[:to].strftime("%B %-d, %Y")}, totaling #{s[:hours]} hours " \
                   "(airframe #{c["airframe"]}, powerplant #{c["powerplant"]}, general #{c["general"]}), as recorded in the " \
                   "entries of this logbook that bear my signature."), size: 11, leading: 3
      pdf.move_down 20
      [ [ "Supervisor signature", "Date" ], [ "Printed name: #{s[:name]}", "Certificate: #{s[:certificate]}" ],
        [ "Employer / repair station", "Telephone or email" ] ].each do |left, right|
        y = pdf.cursor
        signature_line(left, width: 300)
        pdf.move_cursor_to y
        pdf.indent(340) { signature_line(right, width: 300) }
      end
      pdf.move_down 20
      pdf.text "Specimen signature and initials, as used on the entries that follow:", size: 9, color: MUTED
      y = pdf.cursor
      signature_line("Signature", width: 300)
      pdf.move_cursor_to y
      pdf.indent(340) { signature_line("Initials", width: 120) }
    end
  end

  HEADERS = [ "Date", "Aircraft", "ATA / ACS", "Description of work performed", "Airframe", "Power-\nplant", "General",
              "Supervisor / certificate", "Electronic signature", "Supervisor\nsignature" ].freeze
  WIDTHS = [ 50, 72, 56, 236, 34, 34, 34, 82, 70, 52 ].freeze
  # Ink only: no electronic-signature column; the ink column gets its room.
  INK_HEADERS = (HEADERS - [ "Electronic signature" ]).freeze
  INK_WIDTHS = [ 50, 72, 56, 236, 34, 34, 34, 82, 122 ].freeze

  def headers = @ink ? INK_HEADERS : HEADERS
  def widths = @ink ? INK_WIDTHS : WIDTHS

  def entry_row(e)
    sig = e.signature
    esign = if sig
      "#{sig.signed_at.in_time_zone(@tech.time_zone || Time.zone).strftime("%m/%d/%Y")}\nID #{sig.seal.first(8)}#{sig.intact? ? "" : "\nALTERED"}"
    else
      "Not signed"
    end
    cat = ->(c) { e.category == c ? hrs(e.minutes) : "" }
    [ e.performed_on.strftime("%m/%d/%Y"), [ e.aircraft&.n_number, e.aircraft&.description ].compact_blank.join("\n"),
      [ e.ata_chapter.presence && "ATA #{e.ata_chapter}", e.subject_areas.join(" ") ].compact_blank.join("\n"),
      [ MarkdownText.plain(e.description), e.reference.presence && "Ref: #{e.reference}" ].compact_blank.join("\n"),
      cat.("airframe"), cat.("powerplant"), cat.("general"),
      [ e.supervisor_display_name, e.supervisor_display_certificate ].compact_blank.join("\n"), (esign unless @ink), "" ].compact.map { txt(_1) }
  end

  def totals(list) = %w[airframe powerplant general].map { |c| list.select { _1.category == c }.sum(&:minutes) }

  def build_table(rows, extra_rows = [])
    data = [ headers ] + rows + extra_rows
    pdf.make_table(data, column_widths: widths, header: true,
                   cell_style: { size: 7, padding: [ 3, 3 ], border_color: RULE, border_width: 0.5, valign: :top }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = FILL
      t.row(0).size = 6.5
      t.columns(4..6).align = :right
      extra_rows.size.times do |i|
        row = t.row(data.size - 1 - i)
        row.font_style = :bold
        row.background_color = FILL
      end
    end
  end

  def total_rows(page, forward)
    to_date = page.zip(forward).map(&:sum)
    [ [ "Totals this page", page ], [ "Brought forward", forward ], [ "Total to date", to_date ] ].map do |label, t|
      [ { content: label, colspan: 4, align: :right } ] + t.map { hrs(_1) } + [ { content: "", colspan: @ink ? 2 : 3 } ]
    end
  end

  def entry_pages
    return if @entries.empty?
    forward = [ 0, 0, 0 ]
    remaining = @entries.dup
    until remaining.empty?
      pdf.start_new_page
      heading("Logbook entries - #{@tech.name}")
      available = pdf.cursor - 40 # room for the page certification line
      take = 1
      # As many entries as fit with the totals rows underneath.
      while take < remaining.size
        trial = remaining.first(take + 1)
        break if build_table(trial.map { entry_row(_1) }, total_rows(totals(trial), forward)).height > available
        take += 1
      end
      page_entries = remaining.shift(take)
      page_totals = totals(page_entries)
      build_table(page_entries.map { entry_row(_1) }, total_rows(page_totals, forward)).draw
      forward = page_totals.zip(forward).map(&:sum)
      pdf.move_down 4
      pdf.text "I certify that the entries on this page are true and correct.", size: 7, color: MUTED
      y = pdf.cursor
      signature_line("Technician signature", width: 200)
      pdf.move_cursor_to y
      pdf.indent(230) { signature_line("Date", width: 100) }
    end
  end

  def footer
    pdf.repeat(:all, dynamic: true) do
      pdf.bounding_box([ 0, -6 ], width: pdf.bounds.width, height: 14) do
        pdf.fill_color MUTED
        pdf.text txt("#{@tech.name} - AMT experience logbook - printed #{Date.current.iso8601}"), size: 7
        pdf.move_up 9
        pdf.text "Page #{pdf.page_number} of #{pdf.page_count}", size: 7, align: :right
        pdf.fill_color DARK
      end
    end
  end
end
