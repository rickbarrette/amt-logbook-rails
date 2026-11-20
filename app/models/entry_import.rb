# One upload of logbook entries: a spreadsheet CSV (columns matched to
# fields by the technician) or this app's full export (JSON). Every entry
# comes in as a draft to review, then record or send for signature as usual;
# nothing counts toward the experience totals until then.
#
# Rows already in the logbook (same day, hours and description) are skipped,
# so importing the same file twice doesn't duplicate anything. Undo removes
# the imported entries that are still unchanged drafts.
class EntryImport < ApplicationRecord
  KINDS = %w[csv json].freeze
  MAX_BYTES = 5.megabytes

  belongs_to :user
  has_many :work_entries, dependent: :nullify

  validates :kind, inclusion: { in: KINDS }
  validates :data, presence: true
  validate { errors.add(:data, "is larger than #{MAX_BYTES / 1.megabyte} MB") if data.to_s.bytesize > MAX_BYTES }

  scope :recent, -> { order(created_at: :desc) }

  def self.kind_for(filename, data)
    return "json" if filename.to_s.downcase.end_with?(".json") || data.to_s.lstrip.start_with?("{")
    "csv"
  end

  def done? = status == "done"
  def csv = @csv ||= EntryCsv.new(data)
  def date_format = options["date_format"].presence || "mdy"
  def drafts = work_entries.where(status: "draft")

  # Rows turned into entry attributes, without saving: [[attrs, problem], ...]
  def preview(limit = 10) = parsed_rows.first(limit)
  def total_rows = parsed_rows.size

  def run!
    raise ArgumentError, "already imported" if done?
    created = skipped = 0
    problems = []
    existing = user.work_entries.pluck(:performed_on, :minutes, :description).to_set { |d, m, t| dedupe_key(d, m, t) }
    transaction do
      parsed_rows.each_with_index do |(attrs, problem), i|
        line = kind == "csv" ? "Row #{i + 2}" : "Entry #{i + 1}"
        if problem
          problems << "#{line}: #{problem}"
          next skipped += 1
        end
        key = dedupe_key(attrs[:performed_on], attrs[:minutes], attrs[:description])
        if existing.include?(key)
          problems << "#{line}: already in your logbook"
          next skipped += 1
        end
        entry = user.work_entries.new(attrs.except(:n_number).merge(status: "draft", entry_import: self))
        entry.aircraft = aircraft_for(attrs[:n_number])
        # Keep what was typed when it isn't a US registration (or is empty).
        entry.import_details = entry.import_details.merge("aircraft" => attrs[:n_number]) if attrs[:n_number].present? && !entry.aircraft
        if entry.save
          existing << key
          created += 1
        else
          problems << "#{line}: #{entry.errors.full_messages.to_sentence}"
          skipped += 1
        end
      end
      update!(status: "done", imported_at: Time.current, created_count: created, skipped_count: skipped,
              problems: problems.first(200), data: "-") # the file isn't needed any more
    end
  end

  # Removes imported entries nobody has touched since (still drafts).
  def undo!
    count = drafts.destroy_all.size
    update!(created_count: created_count - count)
    count
  end

  private

  def dedupe_key(date, minutes, description) = [ date.to_s, minutes.to_i, description.to_s.squish.downcase ]

  def parsed_rows
    @parsed_rows ||= kind == "json" ? json_rows : csv_rows
  end

  def csv_rows
    suggester = EntrySuggester.new(user:)
    csv.rows.map do |row|
      get = ->(field) { EntryCsv.cell(row, mapping, field) }
      date = EntryCsv.parse_date(get["performed_on"], date_format)
      hours = EntryCsv.parse_hours(get["hours"])
      description = get["description"]
      problem = if date.nil? then "no date I can read (#{get["performed_on"].inspect})"
      elsif hours.nil? || hours <= 0 then "no hours (#{get["hours"].inspect})"
      elsif hours > 24 then "#{hours} hours in one day; split it into days first"
      elsif description.blank? then "no description"
      end
      category = EntryCsv.parse_category(get["category"])
      ata = EntryCsv.parse_ata(get["ata_chapter"])
      areas = EntryCsv.parse_subject_areas(get["subject_areas"])
      details = { "source" => "csv", "file" => filename }
      if description.present? && (category.nil? || ata.nil?)
        if (s = suggester.suggest(description))
          details["suggested"] = [ ("category" unless category), ("ata_chapter" unless ata), ("subject_areas" if areas.empty?) ].compact
          category ||= s.category
          ata ||= s.ata_chapter
          areas = s.subject_areas if areas.empty?
        end
      end
      attrs = { performed_on: date, minutes: hours && (hours * 60).round, description: description.to_s,
                category: category || "general", ata_chapter: ata, subject_areas: areas,
                reference: get["reference"], location: get["location"], n_number: get["n_number"],
                supervisor_name: get["supervisor_name"]&.first(100), supervisor_certificate: get["supervisor_certificate"]&.first(100),
                import_details: details }
      [ attrs, problem ]
    end
  end

  def json_rows
    doc = parsed_json
    doc.fetch("entries", []).map do |e|
      e = e.to_h
      sig = e["signature"].is_a?(Hash) ? e["signature"] : nil
      supervisor = e["supervisor"].is_a?(Hash) ? e["supervisor"] : {}
      date = Date.iso8601(e["performed_on"].to_s) rescue nil
      details = { "source" => "export", "file" => filename, "original_status" => e["status"],
                  "exported_from" => doc.dig("app", "version") }.compact
      if sig
        details["signature"] = sig.slice("signer_name", "certificate_kind", "certificate_number", "signed_at",
                                         "auth_method", "content_digest", "intact")
      end
      category = Faa.categories.key?(e["category"]) ? e["category"] : "general"
      attrs = { performed_on: date, minutes: e["minutes"].to_i, description: e["description"].to_s,
                started_at: e["started_at"], ended_at: e["ended_at"], category:,
                ata_chapter: Faa.ata_chapters.key?(e["ata_chapter"].to_s) ? e["ata_chapter"].to_s : nil,
                subject_areas: Array(e["subject_areas"]).map(&:to_s) & Faa.subject_areas.keys,
                reference: e["reference"], location: e["location"], n_number: e.dig("aircraft", "n_number"),
                supervisor_name: (sig&.dig("signer_name") || supervisor["name"])&.first(100),
                supervisor_certificate: (sig ? "#{Faa.certificate_short(sig["certificate_kind"])} #{sig["certificate_number"]}".strip : supervisor["certificate"])&.first(100),
                import_details: details }
      problem = if date.nil? then "no valid date"
      elsif attrs[:minutes] <= 0 then "no hours"
      elsif attrs[:description].blank? then "no description"
      end
      [ attrs, problem ]
    end
  end

  def parsed_json
    doc = JSON.parse(data)
    raise EntryCsv::Error, "That JSON file isn't an AMT Logbook export." unless doc.is_a?(Hash) && doc["format"] == LogbookExport::FORMAT
    raise EntryCsv::Error, "That export is from a newer version of AMT Logbook; update this server first." if doc["version"].to_i > LogbookExport::VERSION
    doc
  rescue JSON::ParserError
    raise EntryCsv::Error, "That file isn't valid JSON."
  end

  def aircraft_for(n_number)
    # US registrations: N, then a digit 1-9, up to five characters (C-GABC isn't one).
    raw = n_number.to_s.upcase.gsub(/[^0-9A-Z]/, "")
    return unless raw.match?(/\AN?[1-9][0-9A-Z]{0,4}\z/)
    Aircraft.lookup!(raw)
  rescue ActiveRecord::RecordInvalid
    nil
  end
end
