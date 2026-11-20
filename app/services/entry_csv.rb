require "csv"

# Reads a logbook spreadsheet saved as CSV (this app's own CSV export, another
# logbook app's, or a hand-kept spreadsheet): finds the delimiter and
# encoding, guesses which column holds what, and turns cell text into entry
# values. EntryImport does the importing.
class EntryCsv
  MAX_ROWS = 5000

  # field => [label, header words that suggest it]
  FIELDS = {
    "performed_on" => [ "Date", [ "date", "performed", "date performed", "work date", "day" ] ],
    "hours" => [ "Hours", [ "hours", "hrs", "time", "duration", "total time", "hours worked", "elapsed" ] ],
    "description" => [ "Description", [ "description", "work performed", "work", "description of work", "task", "details", "notes", "remarks", "work description" ] ],
    "n_number" => [ "N-number", [ "n-number", "n number", "nnumber", "tail", "tail number", "registration", "aircraft", "aircraft id", "reg" ] ],
    "category" => [ "Category", [ "category", "type", "rating", "airframe/powerplant", "a/p", "section" ] ],
    "ata_chapter" => [ "ATA chapter", [ "ata", "ata chapter", "chapter", "system" ] ],
    "subject_areas" => [ "ACS subject areas", [ "acs", "acs subject areas", "subject areas", "subjects", "acs areas" ] ],
    "reference" => [ "Work order / reference", [ "reference", "work order", "wo", "task card", "ref", "job", "job number", "ticket" ] ],
    "location" => [ "Location", [ "location", "airport", "where", "shop", "place", "station" ] ],
    "supervisor_name" => [ "Supervisor", [ "supervisor", "supervised by", "signed by", "mechanic", "a&p", "instructor", "signer" ] ],
    "supervisor_certificate" => [ "Supervisor's certificate", [ "certificate", "cert", "certificate number", "cert no", "a&p number", "supervisor certificate" ] ]
  }.freeze
  REQUIRED = %w[performed_on hours description].freeze
  DATE_FORMATS = { "mdy" => "Month/day/year (US)", "dmy" => "Day/month/year" }.freeze

  class Error < StandardError; end

  attr_reader :headers, :rows

  def initialize(data)
    text = decode(data)
    raise Error, "The file is empty." if text.strip.empty?
    table = CSV.parse(text, col_sep: delimiter(text), liberal_parsing: true, skip_blanks: true)
    raise Error, "That doesn't look like a CSV file." if table.empty?
    @headers = table.first.map { _1.to_s.strip }
    @rows = table.drop(1).reject { |r| r.all? { _1.to_s.strip.empty? } }
    raise Error, "The file has #{@rows.size} rows; import at most #{MAX_ROWS} at a time." if @rows.size > MAX_ROWS
  rescue CSV::MalformedCSVError => e
    raise Error, "The file couldn't be read as CSV (#{e.message})."
  end

  # { field => column index } from the header row.
  def guess_mapping
    taken = {}
    FIELDS.each_with_object({}) do |(field, (_, words)), mapping|
      index = @headers.each_with_index.find { |h, i| !taken[i] && words.include?(simplify(h)) }&.last
      index ||= @headers.each_with_index.find { |h, i| !taken[i] && words.any? { simplify(h).start_with?(_1) } }&.last
      next unless index
      taken[index] = true
      mapping[field] = index
    end
  end

  def self.cell(row, mapping, field)
    i = mapping[field]
    i.nil? || i.to_s == "" ? nil : unescape(row[i.to_i].to_s.strip).presence
  end

  # Our CSV export prefixes ' to cells a spreadsheet would read as formulas.
  def self.unescape(v) = v.match?(/\A'[=+\-@]/) ? v[1..] : v

  def self.parse_date(value, format = "mdy")
    v = value.to_s.strip
    return if v.empty?
    return Date.iso8601(v[0, 10]) if v.match?(/\A\d{4}-\d{2}-\d{2}/)
    if (m = v.match(%r{\A(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})\z}))
      a, b, y = m.captures.map(&:to_i)
      y += y < 70 ? 2000 : 1900 if y < 100
      month, day = format == "dmy" ? [ b, a ] : [ a, b ]
      return Date.new(y, month, day)
    end
    Date.parse(v) # "Nov 12, 2026", "12 Nov 2026"
  rescue Date::Error, ArgumentError
    nil
  end

  # "1.5", "1,5", "1:30", "1.5 hrs", "90 min" -> 1.5
  def self.parse_hours(value)
    v = value.to_s.strip.downcase
    return if v.empty?
    if (m = v.match(/\A(\d+):(\d{1,2})\z/)) then return m[1].to_i + m[2].to_i / 60.0
    end
    number = v.tr(",", ".")[/\d+(\.\d+)?/]&.to_f or return
    v.match?(/\bmin/) ? number / 60.0 : number
  end

  def self.parse_category(value)
    v = value.to_s.strip.downcase
    return if v.empty?
    return "airframe" if v.match?(/\A(a|af|airframe)\b/) && !v.match?(/\Aa\s*(&|and|\/)\s*p/)
    return "powerplant" if v.match?(/\A(p|pp|powerplant|power plant|engine)\b/)
    "general" if v.match?(/\A(g|gen|general)\b/)
  end

  def self.parse_ata(value)
    chapter = value.to_s[/\d{1,2}/]&.rjust(2, "0")
    chapter if chapter && Faa.ata_chapters.key?(chapter)
  end

  # Codes ("A-II-A G-K") or labels ("Landing Gear Systems; Inspection Concepts and Techniques").
  def self.parse_subject_areas(value)
    v = value.to_s
    return [] if v.strip.empty?
    by_label = Faa.subject_areas.to_h { |code, label| [ label.downcase, code ] }
    codes = v.scan(/\b[GAP](?:-[IV]+)?-[A-Z]\b/i).map(&:upcase) & Faa.subject_areas.keys
    labels = v.split(/[;,|\n]/).filter_map { by_label[_1.strip.downcase] }
    (codes + labels).uniq
  end

  private

  def decode(data)
    text = data.to_s.dup.force_encoding("UTF-8").delete_prefix("﻿")
    text = data.to_s.dup.force_encoding("Windows-1252").encode("UTF-8", invalid: :replace, undef: :replace) unless text.valid_encoding?
    text
  end

  def delimiter(text)
    first = text.each_line.first.to_s
    [ ",", ";", "\t" ].max_by { first.count(_1) }
  end

  def simplify(header) = header.downcase.gsub(/[_:#*]/, " ").squeeze(" ").strip
end
