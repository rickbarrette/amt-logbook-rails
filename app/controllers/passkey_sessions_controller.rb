# Signing in with a passkey: on its own from the sign-in page (any of this
# site's passkeys on the device), or as the second step after a password
# (only that account's passkeys). The passkey proves possession and the
# device verified the person, so it's two factors; it also works while
# password sign-in is locked after failed tries, since it can't be guessed.
class PasskeySessionsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_two_factor_setup
  rate_limit to: 20, within: 3.minutes, with: -> { render json: { error: "Too many tries. Try again later." }, status: :too_many_requests }
  before_action { render(json: { error: "Sign in with #{Sso.label}." }, status: :forbidden) unless Sso.password_login? }

  def options
    user = pending_otp_user
    options = relying_party.options_for_authentication(
      allow: user&.passkeys&.pluck(:external_id), user_verification: "required"
    )
    store_challenge(:authentication, options)
    render json: options
  end

  def create
    pending = pending_otp_user
    passkey = verify_passkey_assertion(:authentication, user: pending)
    user = passkey&.user
    if user.nil? || user.disabled?
      return render(json: { error: "That passkey isn't recognized here. Sign in with your password, or use another passkey." }, status: :unprocessable_entity)
    end
    return_to = session[:return_to_after_authenticating].presence || root_path
    reset_session
    start_new_session_for user
    user.clear_failed_sign_ins!
    render json: { redirect: return_to }
  end
end
