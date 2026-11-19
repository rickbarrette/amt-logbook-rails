class AircraftController < ApplicationController
  def index
    ids = WorkEntry.where(user: [ current_user, *visible_technicians ]).distinct.pluck(:aircraft_id)
    @aircraft = Aircraft.where(id: ids).order(:n_number)
  end

  def show
    @aircraft = Aircraft.find(params[:id])
    @entries = current_user.work_entries.where(aircraft: @aircraft).recent.limit(100)
  end

  # GET /aircraft/lookup?n_number=N12345 — details from the imported FAA
  # registry (or an aircraft already known here), for the entry form.
  def lookup
    n = Aircraft.normalize_n_number(params[:n_number])
    known = Aircraft.find_by(n_number: n)
    record = RegistryRecord.find_by_n_number(n) unless known
    attrs = known&.attributes&.slice(*%w[n_number manufacturer model year_manufactured aircraft_type engine_manufacturer engine_model serial_number]) ||
            record&.aircraft_attributes&.stringify_keys
    if attrs
      render json: attrs.merge(found: true, description: (known || Aircraft.new(attrs.except("source"))).to_s)
    else
      render json: { found: false, n_number: n, registry_loaded: RegistryRecord.exists? }
    end
  end

  def update
    @aircraft = Aircraft.find(params[:id])
    if @aircraft.update(params.expect(aircraft: %i[manufacturer model year_manufactured serial_number aircraft_type engine_manufacturer engine_model]).merge(source: "manual"))
      redirect_to @aircraft, notice: "Aircraft updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  # Fill (or refill) this aircraft's details from the imported FAA registry.
  def refresh
    @aircraft = Aircraft.find(params[:id])
    if @aircraft.refresh_from_registry!
      redirect_to @aircraft, notice: "Updated from the FAA registry."
    else
      redirect_to @aircraft, alert: RegistryRecord.exists? ? "#{@aircraft.n_number} isn't in the FAA registry." : "The FAA registry hasn't been imported yet."
    end
  end

  private

  def visible_technicians = current_user.admin? ? User.all : current_user.technicians
end
