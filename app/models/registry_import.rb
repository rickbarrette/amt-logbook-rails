# An upload of the FAA Releasable Aircraft database (ReleasableAircraft.zip,
# or MASTER.txt alone), processed in the background by RegistryImportJob.
class RegistryImport < ApplicationRecord
  DIR = Rails.root.join("storage/registry")
  belongs_to :user, optional: true

  def upload_path = DIR.join("#{id}-#{File.basename(filename.to_s).gsub(/[^\w.-]/, "_")}")

  def store!(io)
    FileUtils.mkdir_p(DIR)
    File.open(upload_path, "wb") { |f| IO.copy_stream(io, f) }
  end
end
