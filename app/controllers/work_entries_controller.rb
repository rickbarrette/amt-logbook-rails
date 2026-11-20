class WorkEntriesController < ApplicationController
  before_action :set_entry, only: %i[show edit update destroy submit]
  before_action :require_editable, only: %i[edit update submit]

  def index
    @technician = visible_technician(params[:technician_id])
    scope = @technician.work_entries.includes(:aircraft, :supervisor, :signature, :timer).recent
    scope = scope.where(status: params[:status]) if WorkEntry::STATUSES.include?(params[:status])
    scope = scope.where(entry_import_id: params[:import_id]) if params[:import_id].present?
    scope = scope.where(category: params[:category]) if Faa.categories.key?(params[:category])
    scope = scope.joins(:aircraft).where(aircraft: { n_number: Aircraft.normalize_n_number(params[:n_number]) }) if params[:n_number].present?
    @page = [ params[:page].to_i, 1 ].max
    @entries = scope.offset((@page - 1) * 50).limit(51).to_a
    @more = @entries.size > 50
    @entries = @entries.first(50)
  end

  def show
  end

  def new
    @entry = current_user.work_entries.new(performed_on: Date.current, category: "general",
                                           supervisor: current_user.supervisors.one? ? current_user.supervisors.first : nil)
    if (from = params[:from].presence && current_user.work_entries.find_by(id: params[:from]))
      # "…and add another": same day, aircraft, place and supervisor as the one just saved.
      @entry.assign_attributes(from.slice(:performed_on, :category, :location, :reference, :supervisor_id, :supervisor_name, :supervisor_certificate))
      @entry.n_number = from.aircraft&.n_number
    else
      last = current_user.work_entries.recent.first
      @entry.location = last&.location
      @entry.assign_attributes(last.slice(:supervisor_name, :supervisor_certificate)) if Setting.ink_signatures? && last
    end
  end

  def create
    @entry = current_user.work_entries.new(entry_params)
    assign_aircraft
    if @entry.errors.none? && @entry.save
      submit_if_asked
      return redirect_to(new_work_entry_path(from: @entry.id), notice: "#{saved_notice} Add the next one.") if params[:add_another].present?
      redirect_to @entry, notice: saved_notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @entry.n_number = @entry.aircraft&.n_number
  end

  def update
    # While the clock runs, it owns the hours.
    @entry.assign_attributes(@entry.clocking? ? entry_params.except(:hours) : entry_params)
    # Saved by the technician: the imported values have been checked.
    @entry.import_details = @entry.import_details.except("suggested") if @entry.imported?
    assign_aircraft
    if @entry.errors.none? && @entry.save
      submit_if_asked
      redirect_to @entry, notice: saved_notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def submit
    return redirect_to(@entry, alert: "Clock out first: the timer sets this entry's hours.") if @entry.clocking?
    if Setting.ink_signatures?
      @entry.record!
      redirect_to @entry, notice: "Entry recorded. Your supervisor signs it on the printed logbook."
    elsif @entry.supervisor
      @entry.submit!
      redirect_to @entry, notice: "Sent to #{@entry.supervisor.name} to sign."
    else
      redirect_to edit_work_entry_path(@entry), alert: "Choose a supervisor first."
    end
  end

  def destroy
    if @entry.signed?
      redirect_to @entry, alert: "Signed entries can't be deleted."
    else
      @entry.destroy!
      redirect_to work_entries_path, notice: "Entry deleted.", status: :see_other
    end
  end

  private

  # Your own entries, or ones you supervise / administer (read-only).
  def set_entry
    @entry = WorkEntry.find(params[:id])
    allowed = @entry.user_id == current_user.id || @entry.supervisor_id == current_user.id ||
              current_user.admin? || current_user.technicians.exists?(@entry.user_id)
    raise ActiveRecord::RecordNotFound unless allowed
  end

  def require_editable
    return if @entry.user_id == current_user.id && @entry.editable?
    redirect_to @entry, alert: @entry.signed? ? "Signed entries can't be changed." : "This entry can't be changed now."
  end

  def entry_params
    params.expect(work_entry: [ :performed_on, :hours, :category, :ata_chapter, :description, :reference, :location,
                                :supervisor_id, :supervisor_name, :supervisor_certificate, :n_number, subject_areas: [] ])
  end

  def assign_aircraft
    n = @entry.n_number.to_s.strip
    @entry.aircraft = n.present? ? Aircraft.lookup!(n) : nil
  rescue ActiveRecord::RecordInvalid => e
    @entry.errors.add(:n_number, e.record.errors[:n_number].first || "isn't valid")
  end

  # The primary button, or "…and add another" (which does the same).
  def submit_if_asked
    return if params[:submit_for_signature].blank? && params[:add_another].blank?
    return if @entry.clocking? # hours aren't known until clock-out
    if Setting.ink_signatures?
      @entry.record!
    elsif @entry.supervisor
      @entry.submit!
    end
  end

  def saved_notice
    if @entry.submitted? then "Entry sent to #{@entry.supervisor.name} to sign."
    elsif @entry.recorded? then "Entry recorded. Your supervisor signs it on the printed logbook."
    elsif @entry.clocking? then "Entry saved. The clock is still running; clocking out sets the hours."
    else "Entry saved as a draft."
    end
  end
end
