class RegistryImportJob < ApplicationJob
  queue_as :default

  def perform(import)
    import.update!(status: "running")
    count = RegistryImporter.new(import.upload_path).call
    import.update!(status: "done", records_count: count, finished_at: Time.current)
  rescue StandardError => e
    import.update!(status: "failed", error: e.message.first(1000), finished_at: Time.current)
    raise unless e.is_a?(RegistryImporter::Error)
  ensure
    FileUtils.rm_f(import.upload_path)
  end
end
