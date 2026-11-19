# Progress toward the FAA experience requirement and statistics.
class ReportsController < ApplicationController
  def show
    @technician = visible_technician(params[:technician_id])
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @report = ExperienceReport.new(@technician, from: @from, to: @to)
  end

  private

  def parse_date(v) = v.present? ? Date.parse(v) : nil
rescue Date::Error
  nil
end
