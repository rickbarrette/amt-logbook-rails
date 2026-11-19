class WorkEntriesController < ApplicationController
  before_action :set_entry, only: %i[show edit update destroy submit]
  before_action :require_editable, only: %i[edit update submit]

  def index
    @technician = visible_technician(params[:technician_id])
    scope = @technician.work_entries.includes(:aircraft, :supervisor, :signature).recent
    scope = scope.where(status: params[:status]) if WorkEntry::STATUSES.include?(params[:status])
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
  end

  def create
    @entry = current_user.work_entries.new(entry_params)
    assign_aircraft
    if @entry.errors.none? && @entry.save
      submit_if_asked
      redirect_to @entry, notice: @entry.submitted? ? "Entry saved and sent to #{@entry.supervisor.name} to sign." : "Entry saved as a draft."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @entry.n_number = @entry.aircraft&.n_number
  end

  def update
    @entry.assign_attributes(entry_params)
    assign_aircraft
    if @entry.errors.none? && @entry.save
      submit_if_asked
      redirect_to @entry, notice: @entry.submitted? ? "Entry sent to #{@entry.supervisor.name} to sign." : "Entry saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def submit
    if @entry.supervisor
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
                                :supervisor_id, :n_number, subject_areas: [] ])
  end

  def assign_aircraft
    n = @entry.n_number.to_s.strip
    @entry.aircraft = n.present? ? Aircraft.lookup!(n) : nil
  rescue ActiveRecord::RecordInvalid => e
    @entry.errors.add(:n_number, e.record.errors[:n_number].first || "isn't valid")
  end

  def submit_if_asked
    @entry.submit! if params[:submit_for_signature].present? && @entry.supervisor
  end
end
