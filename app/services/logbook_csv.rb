require "csv"

class LogbookCsv
  HEADERS = [ "Date", "N-number", "Aircraft", "Category", "Hours", "ATA chapter", "ACS subject areas", "Description",
              "Reference", "Location", "Status", "Supervisor", "Certificate", "Signed at" ].freeze

  def initialize(entries)
    @entries = entries
  end

  def to_csv
    CSV.generate do |csv|
      csv << HEADERS
      @entries.each do |e|
        sig = e.signature
        csv << [ e.performed_on.iso8601, e.aircraft&.n_number, e.aircraft&.description, e.category_label, e.hours,
                 e.ata_label, e.subject_areas.join(" "), e.description, e.reference, e.location, e.status,
                 sig&.signer_name || e.supervisor&.name, sig&.certificate_label, sig&.signed_at&.iso8601 ].map { safe(_1) }
      end
    end
  end

  private

  # Stop spreadsheet apps treating a cell as a formula.
  def safe(v) = v.is_a?(String) && v.start_with?("=", "+", "-", "@") ? "'#{v}" : v
end
