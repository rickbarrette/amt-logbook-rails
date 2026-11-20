# The server side of WebAuthn (passkeys): the relying party for this site,
# and one-time challenges kept in the session for five minutes.
module PasskeyCeremonies
  extend ActiveSupport::Concern

  CHALLENGE_FOR = 5.minutes
  # Signing entries or downloading a backup with a passkey: confirmed this recently.
  CONFIRMED_FOR = 10.minutes

  included do
    helper_method :passkey_confirmed?
  end

  private

  # Production answers only to its public address (APP_URL / APP_HOST); in
  # development and tests, whatever address the browser used.
  def relying_party
    origin = Rails.env.production? ? Sso.app_url : request.base_url
    WebAuthn::RelyingParty.new(allowed_origins: [ origin ], id: URI(origin).host, name: "AMT Logbook")
  end

  def store_challenge(kind, options)
    session[:"passkey_#{kind}"] = { "challenge" => options.challenge, "at" => Time.current.to_i }
  end

  # The challenge, once: a replayed or stale response is refused.
  def take_challenge(kind)
    stored = session.delete(:"passkey_#{kind}")
    stored["challenge"] if stored.is_a?(Hash) && Time.zone.at(stored["at"].to_i) > CHALLENGE_FOR.ago
  end

  def credential_param = params.require(:credential).to_unsafe_h.to_h

  # Verifies an assertion against this user's (or any) stored passkey; the
  # passkey, or nil.
  def verify_passkey_assertion(kind, user: nil)
    challenge = take_challenge(kind) or return
    raw = credential_param
    passkey = (user ? user.passkeys : Passkey).find_by(external_id: raw["id"].to_s) or return
    credential = relying_party.verify_authentication(raw, challenge, public_key: passkey.public_key,
                                                     sign_count: passkey.sign_count, user_verification: true)
    return unless credential && credential.id == passkey.external_id
    # Discoverable passkeys say whose they are; it has to be the owner.
    return if credential.user_handle && credential.user_handle != passkey.user.webauthn_id
    passkey.used!(credential.sign_count)
    passkey
  # Malformed input from the browser: refuse it.
  rescue WebAuthn::Error, ActionController::ParameterMissing, ArgumentError, KeyError, TypeError => e
    Rails.logger.info("[passkey] rejected #{kind}: #{e.class}")
    nil
  end

  def passkey_confirmed?
    current_user.passkeys.any? && session[:passkey_confirmed_at].to_i > CONFIRMED_FOR.ago.to_i
  end
end
