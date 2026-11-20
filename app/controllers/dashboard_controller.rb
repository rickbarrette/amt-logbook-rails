class DashboardController < ApplicationController
  def show
    @report = ExperienceReport.new(current_user) if current_user.technician?
    @timers = current_user.timers.active.includes(:aircraft, :work_entry).order(:started_at)
    @recent = current_user.work_entries.recent.includes(:aircraft, :supervisor, :timer).limit(8)
    @returned = current_user.work_entries.where(status: "returned").count
    @to_sign = current_user.entries_to_sign.awaiting_signature.count if current_user.supervisor?
  end
end
