require "test_helper"

class SsoTest < ActionDispatch::IntegrationTest
  setup do
    @env = ENV.to_h.slice("OIDC_ISSUER", "OIDC_CLIENT_ID")
    ENV["OIDC_ISSUER"] = "https://auth.example.com/application/o/amt/"
    ENV["OIDC_CLIENT_ID"] = "client"
    OmniAuth.config.test_mode = true
  end

  teardown do
    %w[OIDC_ISSUER OIDC_CLIENT_ID].each { |k| @env[k] ? ENV[k] = @env[k] : ENV.delete(k) }
    OmniAuth.config.mock_auth[:oidc] = nil
    OmniAuth.config.test_mode = false
  end

  def mock(uid:, email:, verified: true, groups: nil)
    raw = { "email_verified" => verified }
    raw["groups"] = groups if groups
    OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(provider: "oidc", uid:, info: { email:, name: "Someone" }, extra: { raw_info: raw })
  end

  def sso_sign_in
    post "/auth/oidc"
    follow_redirect!
  end

  test "sign in links an existing account by verified email" do
    mock(uid: "abc", email: "jane@example.com")
    sso_sign_in
    assert_redirected_to root_url
    assert_equal "abc", users(:tech).reload.sso_uid
  end

  test "unverified email doesn't link" do
    mock(uid: "abc", email: "jane@example.com", verified: false)
    sso_sign_in
    assert_redirected_to new_session_path
    assert_nil users(:tech).reload.sso_uid
  end

  test "an invitation opened first creates the account" do
    inv = Invitation.create!(name: "New Sup", email_address: "newsup@example.com", supervisor: true, technician: false)
    get invitation_path(inv.token)
    mock(uid: "xyz", email: "newsup@corp.example.com")
    sso_sign_in
    user = User.find_by(sso_uid: "xyz")
    assert user.supervisor?
    assert_equal "newsup@corp.example.com", user.email_address
    assert inv.reload.accepted?
    get signatures_path
    assert_response :success, "SSO sessions don't need the app's 2FA"
  end

  test "no account, no invitation" do
    mock(uid: "nobody", email: "stranger@example.com")
    sso_sign_in
    assert_redirected_to new_session_path
    assert_not User.exists?(email_address: "stranger@example.com")
  end

  test "admin group sync" do
    ENV["OIDC_ADMIN_GROUP"] = "amt-admins"
    mock(uid: "abc", email: "jane@example.com", groups: [ "amt-admins" ])
    sso_sign_in
    assert users(:tech).reload.admin?
  ensure
    ENV.delete("OIDC_ADMIN_GROUP")
  end

  test "supervisor signs after confirming with SSO" do
    users(:sup).update!(sso_uid: "sup-uid")
    mock(uid: "sup-uid", email: "sam@example.com")
    sso_sign_in
    get signatures_path
    assert_select "p", /Confirmed with SSO/
    post signatures_path, params: { entry_ids: [ work_entries(:submitted).id ], certificate_id: user_certificates(:sup_ap).id }
    assert work_entries(:submitted).reload.signed?
    assert_equal "sso", work_entries(:submitted).signature.auth_method
  end

  test "SSO confirmation expires" do
    users(:sup).update!(sso_uid: "sup-uid")
    mock(uid: "sup-uid", email: "sam@example.com")
    sso_sign_in
    travel 11.minutes
    post signatures_path, params: { entry_ids: [ work_entries(:submitted).id ], certificate_id: user_certificates(:sup_ap).id }
    assert work_entries(:submitted).reload.submitted?
  end
end
