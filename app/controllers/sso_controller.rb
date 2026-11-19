# Finishes an OpenID Connect sign-in (OmniAuth does the redirects), links or
# unlinks an account, and confirms a supervisor's identity before signing.
#
# Accounts are matched by the provider's stable subject id. The first time,
# an existing account is linked by email only when the provider says the
# email is verified (or OIDC_TRUST_EMAIL is on). Someone without an account
# gets one only from an invitation opened first in the same browser.
class SsoController < ApplicationController
  allow_unauthenticated_access only: %i[callback failure]
  skip_before_action :require_two_factor_setup
  before_action :require_sso
  rate_limit to: 20, within: 3.minutes, only: :callback, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def callback
    auth = request.env["omniauth.auth"]
    return failure unless auth && auth.provider.to_s == Sso::PROVIDER.to_s && auth.uid.present?
    return reauthenticated if authenticated? && current_user.sso_uid == auth.uid.to_s
    return link(auth) if authenticated?

    user = User.find_by(sso_uid: auth.uid.to_s) || link_by_email(auth) || accept_invitation(auth)
    unless user
      return redirect_to new_session_path, alert: "There's no account for #{auth.info&.email.presence || "that sign-in"}. Ask your administrator for an invitation, then open it and choose #{Sso.label}."
    end
    return redirect_to new_session_path, alert: "This account is disabled." if user.disabled?

    sync_admin(user, auth)
    return_to = session[:return_to_after_authenticating]
    reset_session
    start_new_session_for user, via_sso: true
    session[:sso_signed_in_at] = Time.current.to_i
    redirect_to return_to || root_url
  end

  FAILURES = { "invalid_credentials" => "the sign-in wasn't accepted", "csrf_detected" => "the sign-in expired; try again",
               "access_denied" => "access was denied", "timeout" => "the provider didn't answer in time" }.freeze

  def failure
    reason = FAILURES[params[:message].to_s]
    Rails.logger.warn("[sso] sign-in failed: #{params[:message].to_s.truncate(300)}") unless reason
    redirect_to (authenticated? ? profile_path : new_session_path),
                alert: "#{Sso.label} sign-in failed: #{reason || "couldn't reach #{Sso.label}"}."
  end

  def destroy
    return redirect_to(profile_path, alert: "Password sign-in is off, so #{Sso.label} can't be unlinked.") unless Sso.password_login?
    current_user.update!(sso_uid: nil)
    redirect_to profile_path, notice: "Unlinked from #{Sso.label}."
  end

  private

  def require_sso
    raise ActiveRecord::RecordNotFound unless Sso.enabled?
  end

  # Signed in again at the provider (to sign entries): note when, go back.
  def reauthenticated
    session[:sso_signed_in_at] = Time.current.to_i
    redirect_to session.delete(:after_reauth).presence || profile_path, notice: "Confirmed with #{Sso.label}."
  end

  def link(auth)
    owner = User.find_by(sso_uid: auth.uid.to_s)
    if owner && owner != current_user
      redirect_to profile_path, alert: "That #{Sso.label} account is already linked to someone else."
    else
      current_user.update!(sso_uid: auth.uid.to_s)
      redirect_to profile_path, notice: "Linked. You can now sign in with #{Sso.label}."
    end
  end

  def link_by_email(auth)
    email = auth.info&.email.to_s.strip.downcase
    return if email.blank? || !(email_verified?(auth) || Sso.trust_email?)
    user = User.find_by(email_address: email, sso_uid: nil)
    user&.update!(sso_uid: auth.uid.to_s)
    user
  end

  # The invitation opened in this browser before signing in: whoever holds the
  # link is the invitee, so the account takes the provider's email.
  def accept_invitation(auth)
    invitation = Invitation.find_usable(session[:invitation_token]) or return
    email = auth.info&.email.to_s.strip.downcase.presence || invitation.email_address
    return if User.exists?(email_address: email)
    User.transaction do
      user = User.create!(name: invitation.name, email_address: email, admin: invitation.admin, technician: invitation.technician,
                          supervisor: invitation.supervisor, sso_uid: auth.uid.to_s, password: SecureRandom.base58(40))
      invitation.update!(accepted_at: Time.current, user:)
      user
    end
  rescue ActiveRecord::RecordInvalid
    nil
  end

  def email_verified?(auth) = [ true, "true" ].include?(raw_info(auth)["email_verified"])

  # With OIDC_ADMIN_GROUP set, the provider decides who's an admin (skipped
  # when there's no groups claim, so a missing scope can't demote anyone).
  def sync_admin(user, auth)
    return unless Sso.admin_group && raw_info(auth).key?("groups")
    user.update!(admin: Array(raw_info(auth)["groups"]).map(&:to_s).include?(Sso.admin_group))
  end

  def raw_info(auth) = (auth.extra&.raw_info || {}).to_h.stringify_keys
end
