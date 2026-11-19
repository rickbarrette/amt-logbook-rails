class Admin::AirportsController < Admin::BaseController
  def show
    @count = Airport.count
    @update = AirportUpdate.latest
  end

  def create
    return redirect_to(admin_airports_path, notice: "An update is already running.") if AirportUpdate.in_progress.exists?
    AirportUpdateJob.perform_later(AirportUpdate.create!.id)
    redirect_to admin_airports_path, notice: "Updating airports from OurAirports… refresh in a minute."
  end
end
