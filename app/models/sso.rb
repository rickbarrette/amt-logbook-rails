# Single sign-on through an OpenID Connect provider (Authentik, Keycloak,
# Google…), configured with environment variables:
#
#   OIDC_ISSUER             issuer URL, e.g. https://auth.example.com/application/o/amt-logbook/
#   OIDC_CLIENT_ID          client ID
#   OIDC_CLIENT_SECRET      client secret
#   OIDC_PROVIDER_NAME      button label (default "SSO")
#   OIDC_TRUST_EMAIL        "true" to link existing accounts by email even when the
#                           provider doesn't mark the email verified
#   OIDC_ADMIN_GROUP        members of this group are admins, others aren't (needs a "groups" claim)
#   PASSWORD_LOGIN          "false" to turn off email/password sign-in once SSO works
#   APP_URL                 public base URL (default https://APP_HOST)
#
# Accounts still come from invitations: opening an invitation and choosing
# "Sign in with …" creates the account linked to the provider.
module Sso
  PROVIDER = :oidc
  # Signing with SSO needs a sign-in at the provider this recently.
  REAUTH_FOR = 10.minutes

  module_function

  def enabled? = ENV["OIDC_ISSUER"].present? && ENV["OIDC_CLIENT_ID"].present?
  def label = ENV["OIDC_PROVIDER_NAME"].presence || "SSO"
  def trust_email? = ENV["OIDC_TRUST_EMAIL"] == "true"
  def admin_group = ENV["OIDC_ADMIN_GROUP"].presence

  # Password sign-in stays on unless SSO works and it's switched off, so a
  # broken SSO setup can't lock everyone out.
  def password_login? = !enabled? || ENV["PASSWORD_LOGIN"] != "false"

  def app_url
    ENV["APP_URL"].presence&.chomp("/") ||
      "#{ENV.fetch('FORCE_SSL', 'true') == 'true' ? 'https' : 'http'}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"
  end
end
