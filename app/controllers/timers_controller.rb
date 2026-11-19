# Clock in / out. The clock lives on the server, so it keeps going when the
# app is closed and shows the same time on every device.
class TimersController < ApplicationController
  before_action :set_timer, except: %i[index create]

  def index
    @timers = current_user.timers.active.includes(:aircraft).order(:started_at)
    @history = current_user.timers.where.not(stopped_at: nil).includes(:work_entry).order(stopped_at: :desc).limit(20)
  end

  def create
    aircraft = Aircraft.lookup!(params[:n_number]) if params[:n_number].present?
    Timer.start!(user: current_user, aircraft:, category: params[:category].presence, description: params[:description].to_s.first(500))
    redirect_back_or_to timers_path, notice: "Clocked in."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back_or_to timers_path, alert: e.record.errors.full_messages.to_sentence
  end

  def update
    @timer.update!(params.expect(timer: %i[description category]))
    redirect_back_or_to timers_path, notice: "Timer updated."
  end

  def pause
    @timer.pause!
    redirect_back_or_to timers_path
  end

  def resume
    @timer.resume!
    redirect_back_or_to timers_path
  end

  def stop
    entry = @timer.stop!
    redirect_to edit_work_entry_path(entry), notice: "Clocked out: #{entry.hours} hours. Finish the entry and send it to be signed."
  end

  def destroy
    @timer.destroy!
    redirect_back_or_to timers_path, notice: "Timer discarded.", status: :see_other
  end

  private

  def set_timer
    @timer = current_user.timers.active.find(params[:id])
  end
end
