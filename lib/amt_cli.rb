require "thor"

# Admin command line: `bin/amt <command>` inside the container, e.g.
#
#   docker exec amt-logbook bin/amt users
#   docker exec amt-logbook bin/amt reset-2fa jane@example.com
#
# For when nobody can reach Admin in the browser (lost phone, lockout, no
# other admin), and for jobs that suit a shell (importing the FAA registry
# from a file, backups, verifying every signature). Shell access to the
# container already means full control, so commands don't ask for passwords;
# changes are written to the app log.
class AmtCli < Thor
  def self.exit_on_failure? = true
  package_name "amt"

  map "reset-password" => :reset_password, "reset-2fa" => :reset_two_factor, "sign-out" => :sign_out,
      "setup-code" => :setup_code, "import-registry" => :import_registry, "update-airports" => :update_airports,
      "verify-signatures" => :verify_signatures, "make-admin" => :make_admin

  desc "status", "Version, settings, counts and health"
  def status
    print_table [
      [ "Version", "#{Rails.application.config.x.version} (build #{Rails.application.config.x.app_revision})" ],
      [ "Address", Sso.app_url ],
      [ "Signatures", Setting.signature_mode == "ink" ? "ink only" : "electronic and ink" ],
      [ "Two-factor", Setting.two_factor_for_everyone? ? "required for everyone" : "required for admins and supervisors" ],
      [ "Email", ENV["SMTP_ADDRESS"].present? ? "SMTP (#{ENV["SMTP_ADDRESS"]})" : "not set up (use reset-password links)" ],
      [ "Single sign-on", Sso.enabled? ? "#{Sso.label}#{" (password sign-in off)" unless Sso.password_login?}" : "off" ],
      [ "Users", user_summary ],
      [ "Entries", "#{WorkEntry.count} (#{WorkEntry.signed.count} signed, #{WorkEntry.where(status: "recorded").count} recorded)" ],
      [ "Passkeys", Passkey.count.to_s ],
      [ "FAA registry", RegistryRecord.count.positive? ? "#{RegistryRecord.count} aircraft" : "not imported" ],
      [ "Airports", Airport.count.to_s ],
      [ "Database", number_to_human_size(File.size(db_path)) ],
      [ "First admin", User.exists? ? "created" : "not yet: run `bin/amt setup-code`" ]
    ]
  end

  desc "users", "List accounts"
  def users
    rows = User.ordered.includes(:passkeys).map do |u|
      flags = [ ("admin" if u.admin?), ("supervisor" if u.supervisor?), ("technician" if u.technician?) ].compact.join(",")
      state = if u.disabled? then "DISABLED" elsif u.locked? then "locked" else "" end
      second = [ ("app" if u.otp_enabled?), ("passkey×#{u.passkeys.size}" if u.passkeys.any?) ].compact.join("+").presence || "-"
      [ u.email_address, u.name, flags, second, u.last_signed_in_at&.to_date&.iso8601 || "never", state ]
    end
    print_table [ %w[EMAIL NAME ROLES 2FA LAST_SIGN_IN STATE] ] + rows
  end

  desc "invite EMAIL NAME", "Make an invitation link (14 days) to send by hand"
  option :admin, type: :boolean, default: false, desc: "Administrator"
  option :supervisor, type: :boolean, default: false, desc: "Can sign entries"
  option :technician, type: :boolean, default: true, desc: "Keeps a logbook (--no-technician for admins/supervisors only)"
  def invite(email, name)
    invitation = Invitation.create!(email_address: email, name:, admin: options[:admin], supervisor: options[:supervisor],
                                    technician: options[:technician])
    audit("invited #{invitation.email_address}#{" as admin" if options[:admin]}")
    say "Invitation for #{invitation.name}, valid until #{invitation.expires_at.to_date.iso8601}:"
    say url("/invitations/#{invitation.token}")
  rescue ActiveRecord::RecordInvalid => e
    fail!(e.record.errors.full_messages.to_sentence)
  end

  desc "reset-password EMAIL", "Make a password reset link (works for an hour, once)"
  def reset_password(email)
    user = find_user(email)
    audit("made a password reset link for #{user.email_address}")
    say "Password reset link for #{user.name} (works for an hour):"
    say url("/passwords/#{user.password_reset_token}/edit")
  end

  desc "reset-2fa EMAIL", "Lost phone: remove their authenticator app and passkeys, sign them out"
  option :yes, type: :boolean, aliases: "-y", desc: "Don't ask"
  def reset_two_factor(email)
    user = find_user(email)
    confirm!("Remove #{user.name}'s authenticator app and #{user.passkeys.count} passkey(s)?")
    user.reset_second_factors!
    user.sessions.destroy_all
    audit("reset two-factor for #{user.email_address}")
    say "Done. #{user.name} signs in with their password#{" and must set two-factor up again" if user.otp_required?}."
  end

  desc "unlock EMAIL", "Lift a sign-in lockout after failed tries"
  def unlock(email)
    user = find_user(email)
    user.update_columns(failed_sign_ins: 0, locked_until: nil)
    audit("unlocked #{user.email_address}")
    say "#{user.name} can sign in again."
  end

  desc "disable EMAIL", "Block an account and sign it out everywhere (records are kept)"
  option :yes, type: :boolean, aliases: "-y", desc: "Don't ask"
  def disable(email)
    user = find_user(email)
    fail!("#{user.name} is the only active admin; make someone else admin first.") if last_admin?(user)
    confirm!("Disable #{user.name}?")
    user.update!(disabled_at: Time.current)
    user.sessions.destroy_all
    audit("disabled #{user.email_address}")
    say "#{user.name} is disabled."
  end

  desc "enable EMAIL", "Re-enable a disabled account (also lifts a lockout)"
  def enable(email)
    user = find_user(email)
    user.update!(disabled_at: nil, failed_sign_ins: 0, locked_until: nil)
    audit("enabled #{user.email_address}")
    say "#{user.name} is enabled."
  end

  desc "make-admin EMAIL", "Give an account admin access (--off to remove it)"
  option :off, type: :boolean, default: false, desc: "Remove admin access instead"
  def make_admin(email)
    user = find_user(email)
    fail!("#{user.name} is the only active admin.") if options[:off] && last_admin?(user)
    user.update!(admin: !options[:off])
    audit("#{options[:off] ? "removed admin from" : "made admin"} #{user.email_address}")
    say options[:off] ? "#{user.name} is no longer an admin." : "#{user.name} is an admin. They'll need two-factor at their next sign-in."
  end

  desc "sign-out EMAIL", "Sign an account out on every device"
  def sign_out(email)
    user = find_user(email)
    count = user.sessions.destroy_all.size
    audit("signed out #{user.email_address} (#{count} sessions)")
    say "Signed #{user.name} out of #{count} #{"device".pluralize(count)}."
  end

  desc "setup-code", "Show the one-time code for creating the first admin"
  def setup_code
    fail!("The first admin already exists. Use `bin/amt invite EMAIL NAME --admin` for another.") if User.exists?
    say "Setup code: #{SetupCode.current}"
    say "Open #{url("/setup/new")} and enter it."
  end

  desc "settings [KEY VALUE]", "Show settings, or change one (signature_mode, require_two_factor)"
  def settings(key = nil, value = nil)
    allowed = { "signature_mode" => Setting::SIGNATURE_MODES, "require_two_factor" => Setting::TWO_FACTOR_POLICIES }
    if key.nil?
      return print_table(allowed.map { |k, choices| [ k, Setting.get(k), "(#{choices.keys.join(" | ")})" ] })
    end
    fail!("Unknown setting #{key}. Settings: #{allowed.keys.join(", ")}") unless allowed.key?(key)
    fail!("#{key} can be: #{allowed[key].keys.join(", ")}") unless allowed[key].key?(value)
    Setting.set(key, value)
    audit("set #{key} to #{value}")
    say "#{key} = #{value}"
  end

  desc "backup PATH", "Write a copy of the database to PATH (safe while running)"
  option :include_reference, type: :boolean, default: false, desc: "Include the FAA registry and airports"
  def backup(path)
    source = DatabaseBackup.new(include_reference: options[:include_reference]).create!
    FileUtils.mkdir_p(File.dirname(File.expand_path(path)))
    FileUtils.mv(source, path)
    audit("wrote a database backup")
    say "Backup written to #{path} (#{number_to_human_size(File.size(path))}). Restoring needs the same SECRET_KEY_BASE."
  end

  desc "import-registry PATH", "Import the FAA ReleasableAircraft.zip (or MASTER.txt) from a file"
  def import_registry(path)
    fail!("No file at #{path}") unless File.file?(path)
    import = RegistryImport.create!(filename: File.basename(path), status: "running")
    say "Importing #{File.basename(path)}… (a few minutes for the full registry)"
    count = RegistryImporter.new(path).call
    import.update!(status: "done", records_count: count, finished_at: Time.current)
    audit("imported the FAA registry (#{count} aircraft)")
    say "Imported #{count} aircraft."
  rescue RegistryImporter::Error => e
    import&.update!(status: "failed", error: e.message, finished_at: Time.current)
    fail!(e.message)
  end

  desc "update-airports", "Download OurAirports now and update the airport list"
  def update_airports
    say "Downloading airports…"
    counts = AirportData.refresh!
    AirportUpdate.create!(status: "done", started_at: Time.current, finished_at: Time.current, created_count: counts[:created],
                          updated_count: counts[:updated], removed_count: counts[:removed])
    say "#{counts[:created]} added, #{counts[:updated]} changed, #{counts[:removed]} removed (#{Airport.count} airports)."
  end

  desc "verify-signatures", "Check every electronic signature's seal and content"
  def verify_signatures
    bad = []
    total = 0
    EntrySignature.includes(work_entry: [ :user, :aircraft ]).find_each do |sig|
      total += 1
      next if sig.intact?
      reason = sig.seal_valid? ? "entry changed after signing" : "seal doesn't match (edited record, or a different SECRET_KEY_BASE)"
      bad << [ sig.work_entry.performed_on.iso8601, sig.work_entry.user.name, sig.signer_name, "entry ##{sig.work_entry_id}", reason ]
    end
    say "#{total} signatures checked, #{total - bad.size} intact."
    return if bad.empty?
    print_table [ %w[DATE TECHNICIAN SIGNED_BY ENTRY PROBLEM] ] + bad
    exit 1
  end

  desc "export EMAIL", "Write a technician's logbook to a file (full JSON export, CSV or PDF)"
  option :format, default: "json", enum: %w[json csv pdf]
  option :out, desc: "Output path (default: amt-logbook-NAME-DATE.FORMAT here)"
  def export(email)
    user = find_user(email)
    entries = user.work_entries.includes(:aircraft, :signature, :supervisor).chronological
    data = case options[:format]
    when "json" then LogbookExport.new(user).to_json
    when "csv" then LogbookCsv.new(entries).to_csv
    else LogbookPdf.new(user, entries.where(status: LogbooksController::PRINTABLE).to_a, report: ExperienceReport.new(user)).render
    end
    path = options[:out] || "amt-logbook-#{user.name.parameterize}-#{Date.current.iso8601}.#{options[:format]}"
    File.binwrite(path, data)
    audit("exported #{user.email_address}'s logbook (#{options[:format]})")
    say "Wrote #{path} (#{entries.size} entries)."
  end

  private

  include ActionView::Helpers::NumberHelper

  def find_user(email)
    User.find_by(email_address: email.to_s.strip.downcase) || fail!("No account with email #{email}. `bin/amt users` lists them.")
  end

  def last_admin?(user) = user.admin? && User.active.where(admin: true).where.not(id: user.id).none?

  def user_summary
    "#{User.count} (#{User.where(admin: true).count} admin, #{User.where(supervisor: true).count} supervisor, " \
      "#{User.where(technician: true).count} technician, #{User.where.not(disabled_at: nil).count} disabled)"
  end

  def url(path) = "#{Sso.app_url}#{path}"
  def db_path = Rails.root.join(WorkEntry.connection_db_config.database)

  def confirm!(question)
    return if options[:yes]
    fail!("Cancelled.") unless yes?("#{question} [y/N]")
  end

  def fail!(message)
    raise Thor::Error, message
  end

  def audit(what) = Rails.logger.info("[cli] #{what}")
end
