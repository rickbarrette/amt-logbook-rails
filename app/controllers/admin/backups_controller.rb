# Download a copy of the whole server's database (Admin → Backup), after
# confirming who you are: it holds every account and logbook.
class Admin::BackupsController < Admin::BaseController
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to admin_backup_path, alert: "Try again later." }

  def show
    @sso_confirmed = sso_confirmed?
    session[:after_reauth] = admin_backup_path if Sso.enabled? && current_user.sso_linked?
    @counts = { "Users" => User.count, "Entries" => WorkEntry.count, "Signatures" => EntrySignature.count }
    @reference = { "FAA registry records" => RegistryRecord.count, "Airports" => Airport.count }
  end

  def create
    how = confirm_identity or
      return redirect_to(admin_backup_path, alert: "Your password or authenticator code didn't match.")
    session.delete(:sso_signed_in_at) if how == "sso"
    backup = DatabaseBackup.new(include_reference: params[:include_reference] == "1")
    Rails.logger.info("[backup] database backup downloaded by user #{current_user.id}")
    send_file backup.create!, filename: backup.filename, type: "application/vnd.sqlite3", disposition: "attachment"
  end
end
