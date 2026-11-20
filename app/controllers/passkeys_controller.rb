# Profile → Passkeys: add one (this device's Face ID / Touch ID / Windows
# Hello / PIN, a phone, or a security key) or remove one.
#
# Adding a passkey gives lasting access, so it needs a recent sign-in (the
# last 10 minutes), a fresh single sign-on, or the account password.
class PasskeysController < ApplicationController
  skip_before_action :require_two_factor_setup # setting one up is how you meet that requirement
  rate_limit to: 20, within: 10.minutes, only: %i[options create destroy], with: -> { head :too_many_requests }

  RECENT_SIGN_IN = 10.minutes

  def options
    unless allowed_to_add?
      return render(json: { error: "Enter your password to add a passkey." }, status: :forbidden)
    end
    options = relying_party.options_for_registration(
      user: { id: current_user.webauthn_handle, name: current_user.email_address, display_name: current_user.name },
      exclude: current_user.passkeys.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "required" }
    )
    store_challenge(:registration, options)
    session[:passkey_name] = params[:name].to_s.strip.first(60).presence
    render json: options
  end

  def create
    challenge = take_challenge(:registration)
    return render(json: { error: "That took too long. Try again." }, status: :unprocessable_entity) unless challenge
    credential = relying_party.verify_registration(credential_param, challenge, user_verification: true)
    passkey = current_user.passkeys.create!(external_id: credential.id, public_key: credential.public_key,
                                            sign_count: credential.sign_count, name: session.delete(:passkey_name) || default_name)
    flash[:notice] = "Passkey “#{passkey.name}” added. You can sign in with it."
    render json: { redirect: params[:return_to] == "two_factor" ? root_path : profile_path(anchor: "passkeys") }
  rescue WebAuthn::Error, ActiveRecord::RecordInvalid, ActionController::ParameterMissing, ArgumentError, KeyError, TypeError, NoMethodError => e
    Rails.logger.info("[passkey] registration rejected: #{e.class}")
    render json: { error: "That passkey couldn't be added. Try again." }, status: :unprocessable_entity
  end

  def destroy
    passkey = current_user.passkeys.find(params[:id])
    if current_user.otp_required? && !current_user.otp_enabled? && current_user.passkeys.count == 1
      return redirect_to(profile_path(anchor: "passkeys"), alert: "That's your only second factor. Add another passkey or an authenticator app first.")
    end
    passkey.destroy!
    redirect_to profile_path(anchor: "passkeys"), notice: "Passkey “#{passkey.name}” removed.", status: :see_other
  end

  private

  def allowed_to_add?
    Current.session.created_at > RECENT_SIGN_IN.ago || sso_confirmed? ||
      (params[:password].present? && current_user.authenticate(params[:password].to_s))
  end

  # "Passkey on Mac", from the browser, when no name was typed.
  def default_name
    device = case request.user_agent.to_s
    when /iPhone/ then "iPhone"
    when /iPad/ then "iPad"
    when /Android/ then "Android"
    when /Macintosh/ then "Mac"
    when /Windows/ then "Windows"
    when /Linux/ then "Linux"
    end
    device ? "Passkey on #{device}" : "Passkey"
  end
end
