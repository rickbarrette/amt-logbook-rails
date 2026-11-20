# A consistent copy of the main database (SQLite VACUUM INTO, safe while the
# app runs) for an admin to download. Sign-in sessions are left out, so a
# restored copy signs everyone out; the FAA registry and airport tables are
# left out unless asked for (they're big and re-downloadable).
#
# Restoring: stop the app, replace storage/production.sqlite3 with the file,
# start it again, with the same SECRET_KEY_BASE (it unlocks authenticator
# secrets and verifies e-signature seals).
class DatabaseBackup
  DIR = Rails.root.join("tmp/backups")
  REFERENCE_TABLES = %w[registry_records airports].freeze
  KEEP_FOR = 1.hour

  def initialize(include_reference: false)
    @include_reference = include_reference
  end

  def filename = "amt-logbook-backup-#{Time.current.strftime("%Y%m%d-%H%M")}.sqlite3"

  # Path to the copy; old copies are cleaned up on the next backup.
  def create!
    FileUtils.mkdir_p(DIR)
    Dir.glob(DIR.join("*.sqlite3")).each { File.delete(_1) if File.mtime(_1) < KEEP_FOR.ago }
    path = DIR.join("backup-#{SecureRandom.hex(12)}.sqlite3").to_s
    # Its own connection: VACUUM can't run inside a transaction.
    source = SQLite3::Database.new(Rails.root.join(WorkEntry.connection_db_config.database).to_s)
    source.busy_timeout = 5000
    source.execute("VACUUM INTO ?", [ path ])
    source.close
    db = SQLite3::Database.new(path)
    db.execute("DELETE FROM sessions")
    REFERENCE_TABLES.each { db.execute("DELETE FROM #{_1}") } unless @include_reference
    db.execute("VACUUM")
    db.close
    path
  end
end
