# OpenID Connect single sign-on; see app/models/sso.rb for the settings.
# The provider is registered at boot, so changing OIDC_* needs a restart.
# (Same as Sso.app_url; app classes can't be used in initializers.)
app_url = ENV["APP_URL"].presence&.chomp("/") ||
          "#{ENV.fetch('FORCE_SSL', 'true') == 'true' ? 'https' : 'http'}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"

Rails.application.config.middleware.use OmniAuth::Builder do
  if (ENV["OIDC_ISSUER"].present? && ENV["OIDC_CLIENT_ID"].present?) || Rails.env.test?
    provider :openid_connect,
             name: :oidc,
             issuer: ENV["OIDC_ISSUER"],
             discovery: true,
             scope: %i[openid email profile],
             response_type: :code,
             pkce: true,
             allow_authorize_params: %i[prompt], # prompt=login: sign in again before signing entries
             client_options: {
               identifier: ENV["OIDC_CLIENT_ID"],
               secret: ENV["OIDC_CLIENT_SECRET"],
               redirect_uri: "#{app_url}/auth/oidc/callback"
             }
  end
end

OmniAuth.config.allowed_request_methods = [ :post ] # starts from a CSRF-protected form
OmniAuth.config.full_host = app_url unless Rails.env.test? # never trust the request's Host
OmniAuth.config.logger = Rails.logger
