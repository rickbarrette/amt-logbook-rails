# Print & export: the printable logbook (PDF, with lines for ink signatures),
# a CSV for spreadsheets, and the full export (JSON) that Import reads back.
class LogbooksController < ApplicationController
  # What to include: label, statuses (electronic signatures / ink only).
  SCOPES = {
    "counted" => [ "Signed entries", %w[signed], %w[signed submitted recorded] ],
    "awaiting" => [ "Signed and awaiting signature", %w[signed submitted], %w[signed submitted recorded] ],
    "all" => [ "Everything, including drafts", WorkEntry::STATUSES, WorkEntry::STATUSES ]
  }.freeze
  PRINTABLE = %w[signed submitted recorded].freeze

  def show
    @technician = visible_technician(params[:technician_id])
  end

  def export
    technician = visible_technician(params[:technician_id])
    from = params[:from].presence && Date.parse(params[:from])
    to = params[:to].presence && Date.parse(params[:to])
    entries = technician.work_entries.between(from, to).where(status: statuses)
    entries = entries.where(category: params[:category]) if Faa.categories.key?(params[:category])
    name = "amt-logbook-#{technician.name.parameterize}-#{Date.current.iso8601}"

    respond_to do |format|
      format.pdf do
        printable = entries.where(status: PRINTABLE).includes(:aircraft, :signature, :supervisor).chronological
        pdf = LogbookPdf.new(technician, printable.to_a, report: ExperienceReport.new(technician, from:, to:), from:, to:).render
        send_data pdf, filename: "#{name}.pdf", type: "application/pdf", disposition: params[:download] ? "attachment" : "inline"
      end
      format.csv { send_data LogbookCsv.new(entries.includes(:aircraft, :signature, :supervisor).chronological).to_csv, filename: "#{name}.csv", type: "text/csv" }
      format.json do
        export = LogbookExport.new(technician, entries)
        send_data export.to_json, filename: export.filename, type: "application/json", disposition: "attachment"
      end
    end
  rescue Date::Error
    redirect_to logbook_path, alert: "Check the dates."
  end

  private

  def statuses
    # Older links: include_unsigned=1 meant signed + awaiting.
    key = SCOPES.key?(params[:entries]) ? params[:entries] : (params[:include_unsigned] == "1" ? "awaiting" : "counted")
    key = "all" if params[:format] == "json" && params[:entries].blank?
    SCOPES[key][Setting.ink_signatures? ? 2 : 1]
  end
end
