# Upload the FAA Releasable Aircraft database for N-number lookups.
class Admin::RegistryImportsController < Admin::BaseController
  def index
    @imports = RegistryImport.order(created_at: :desc).limit(10)
    @count = RegistryRecord.count
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
