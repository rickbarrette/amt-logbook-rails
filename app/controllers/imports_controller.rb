# Importing entries: upload a spreadsheet CSV or an AMT Logbook export,
# match the CSV's columns to fields and preview, import as drafts, then
# record or send them for signature in one go (or undo the import).
class ImportsController < ApplicationController
  before_action :require_technician
  before_action :set_import, except: %i[index create]
  rate_limit to: 20, within: 10.minutes, only: :create, with: -> { redirect_to imports_path, alert: "Try again later." }

  def index
    @imports = current_user.entry_imports.recent.limit(20)
  end

  def create
    file = params[:file]
    return redirect_to(imports_path, alert: "Choose a file to import.") unless file.respond_to?(:read)
    return redirect_to(imports_path, alert: "That file is over #{EntryImport::MAX_BYTES / 1.megabyte} MB.") if file.size > EntryImport::MAX_BYTES
    if file.original_filename.to_s.downcase.end_with?(".xlsx", ".xls", ".numbers", ".ods")
      return redirect_to(imports_path, alert: "Save the spreadsheet as CSV first (File → Save As / Download → CSV), then import that.")
    end
    data = file.read
    import = current_user.entry_imports.new(filename: file.original_filename.to_s.first(200), data:,
                                            kind: EntryImport.kind_for(file.original_filename, data))
    import.mapping = import.csv.guess_mapping if import.kind == "csv"
    import.preview(1) # reads the file: reports a bad one now
    import.save!
    redirect_to import_path(import)
  rescue EntryCsv::Error => e
    redirect_to imports_path, alert: e.message
  end

  def show
    @preview = @import.preview(10) unless @import.done?
    @total = @import.total_rows unless @import.done?
  rescue EntryCsv::Error => e
    @error = e.message
  end

  # Saves the column matching (and, with "import", imports).
  def update
    return redirect_to(import_path(@import), alert: "Already imported.") if @import.done?
    if @import.kind == "csv"
      mapping = params.fetch(:mapping, {}).permit(*EntryCsv::FIELDS.keys).to_h.compact_blank
      @import.update!(mapping:, options: { "date_format" => EntryCsv::DATE_FORMATS.key?(params[:date_format]) ? params[:date_format] : "mdy" })
      missing = EntryCsv::REQUIRED - mapping.keys
      if params[:import] && missing.any?
        return redirect_to(import_path(@import), alert: "Choose the column for #{missing.map { EntryCsv::FIELDS[_1].first.downcase }.to_sentence}.")
      end
    end
    return redirect_to(import_path(@import)) unless params[:import]
    @import.run!
    redirect_to import_path(@import), notice: "Imported #{@import.created_count} #{"entry".pluralize(@import.created_count)} as drafts."
  rescue EntryCsv::Error => e
    redirect_to import_path(@import), alert: e.message
  end

  def destroy
    return redirect_to(import_path(@import), alert: "Undo the import instead.") if @import.done?
    @import.destroy!
    redirect_to imports_path, notice: "Import cancelled.", status: :see_other
  end

  def undo
    count = @import.undo!
    redirect_to import_path(@import), notice: "Removed #{count} imported #{"draft".pluralize(count)}. Entries you'd already changed, recorded or sent stay."
  end

  # Records (ink mode) or sends for signature every imported draft.
  def finish
    drafts = @import.drafts.to_a
    if Setting.ink_signatures?
      drafts.each(&:record!)
      redirect_to import_path(@import), notice: "Recorded #{drafts.size} #{"entry".pluralize(drafts.size)}."
    else
      supervisor = current_user.supervisors.find_by(id: params[:supervisor_id])
      return redirect_to(import_path(@import), alert: "Choose a supervisor.") unless supervisor
      drafts.each { _1.submit!(to: supervisor) }
      redirect_to import_path(@import), notice: "Sent #{drafts.size} #{"entry".pluralize(drafts.size)} to #{supervisor.name} to sign."
    end
  end

  private

  def set_import
    @import = current_user.entry_imports.find(params[:id])
  end

  def require_technician
    redirect_to root_path, alert: "Imports are for technicians' own logbooks." unless current_user.technician?
  end
end
