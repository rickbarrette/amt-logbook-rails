# The printable logbook (PDF, with lines for ink signatures) and a CSV export.
class LogbooksController < ApplicationController
  def show
    @technician = visible_technician(params[:technician_id])
  end

  def export
    technician = visible_technician(params[:technician_id])
    from = params[:from].presence && Date.parse(params[:from])
    to = params[:to].presence && Date.parse(params[:to])
    statuses = if Setting.ink_signatures? then %w[signed submitted recorded]
    elsif params[:include_unsigned] == "1" then %w[signed submitted]
    else %w[signed]
    end
    entries = technician.work_entries.between(from, to).where(status: statuses).includes(:aircraft, :signature, :supervisor).chronological
    name = "amt-logbook-#{technician.name.parameterize}-#{Date.current.iso8601}"

    respond_to do |format|
      format.pdf do
        pdf = LogbookPdf.new(technician, entries.to_a, report: ExperienceReport.new(technician, from:, to:), from:, to:).render
        send_data pdf, filename: "#{name}.pdf", type: "application/pdf", disposition: params[:download] ? "attachment" : "inline"
      end
      format.csv { send_data LogbookCsv.new(entries).to_csv, filename: "#{name}.csv", type: "text/csv" }
    end
  rescue Date::Error
    redirect_to logbook_path, alert: "Check the dates."
  end
end
