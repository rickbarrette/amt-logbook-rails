# Content Security Policy: the browser runs only this site's own scripts (and
# the inline import map and charts, which carry a nonce), so
# anything injected into a page can't execute. Pages can't be framed by
# other sites, and forms post only here (or to the single sign-on provider,
# which the sign-in form is redirected to).
sso_origin = begin
  uri = URI(ENV["OIDC_ISSUER"].to_s)
  "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless [ 80, 443 ].include?(uri.port)}" if uri.host
rescue URI::InvalidURIError
  nil
end

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline # Turbo's progress bar and chart sizes set inline styles
    policy.img_src     :self, :data          # the authenticator QR code is a data: image
    policy.font_src    :self
    policy.connect_src :self
    policy.manifest_src :self
    policy.worker_src  :self
    policy.object_src  :none
    policy.base_uri    :self
    policy.frame_ancestors :none
    policy.form_action :self, *sso_origin
  end

  # One nonce per browser session: Turbo swaps pages in without reloading, so
  # scripts on later pages must match the nonce the first page was given.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s.presence || SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end

# Charts are drawn by an inline script; give it the page's nonce.
Chartkick.options[:nonce] = true
