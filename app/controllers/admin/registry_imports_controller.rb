# Upload the FAA Releasable Aircraft database for N-number lookups.
class Admin::RegistryImportsController < Admin::BaseController
  def index
    @imports = RegistryImport.order(created_at: :desc).limit(10)
    @count = RegistryRecord.count
    @refreshable = Aircraft.registry_refreshable.count
  end

  # Aircraft added before the registry was imported (or filled from an older
  # import) get the current details; ones edited by hand are left alone.
  def refresh_aircraft
    count = Aircraft.refresh_from_registry!
    redirect_to admin_registry_imports_path, notice: "Updated #{count} #{"aircraft"} from the registry."
  end

  def create
    file = params[:file]
    return redirect_to(admin_registry_imports_path, alert: "Choose a file.") unless file.respond_to?(:read)
    import = RegistryImport.create!(user: current_user, filename: file.original_filename)
    import.store!(file)
    RegistryImportJob.perform_later(import)
    redirect_to admin_registry_imports_path, notice: "Importing… this takes a minute or two. Refresh to check."
  end
end
