class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :require_two_factor_setup
  around_action :use_time_zone

  private

  # Admins and supervisors must turn on an authenticator before going further.
  def require_two_factor_setup
    return unless current_user&.otp_required? && !current_user.otp_enabled? && !Current.session&.via_sso?
    redirect_to new_two_factor_path, alert: "Set up an authenticator app to continue. Supervisors and admins need two-factor sign-in."
  end

  def use_time_zone(&)
    Time.use_zone(current_user&.time_zone.presence || Time.zone, &)
  end

  def require_admin
    head :forbidden unless current_user.admin?
  end

  def require_supervisor
    redirect_to root_path, alert: "Only supervisors can do that." unless current_user.supervisor?
  end

  def require_electronic_signatures
    redirect_to root_path, alert: "Signatures are in ink on the printed logbook (Admin → Settings)." if Setting.ink_signatures?
  end

  # Technicians whose records the current user may see.
  def visible_technician(id)
    return current_user if id.blank? || id.to_s == current_user.id.to_s
    scope = current_user.admin? ? User.all : current_user.technicians
    scope.find(id)
  end
  helper_method :visible_technician

  # Signed in at the SSO provider within the last few minutes, as this user.
  def sso_confirmed?
    Sso.enabled? && current_user.sso_linked? &&
      session[:sso_signed_in_at].to_i > Sso::REAUTH_FOR.ago.to_i
  end

  # Before something sensitive: a fresh SSO sign-in, or password plus
  # authenticator code from the form. Returns how, or nil.
  def confirm_identity
    return "sso" if sso_confirmed?
    ok = current_user.authenticate(params[:password].to_s) && current_user.verify_second_factor(params[:code])
    current_user.register_failed_sign_in! unless ok
    ok ? "password_totp" : nil
  end
end
