require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "first run creates the admin, who must set up 2FA" do
    WorkEntry.delete_all
    Supervision.delete_all
    UserCertificate.delete_all
    User.delete_all
    get root_path
    assert_redirected_to new_setup_path
    user = { name: "First Admin", email_address: "first@example.com", password: PASSWORD, password_confirmation: PASSWORD }
    post setup_path, params: { user:, setup_code: "WRONG" }
    assert_response :unprocessable_entity
    assert_not User.exists?
    post setup_path, params: { user:, setup_code: SetupCode.current }
    assert_redirected_to new_two_factor_path
    assert User.find_by(email_address: "first@example.com").admin?
    get root_path
    assert_redirected_to new_two_factor_path
  end

  test "password sign-in, then authenticator code when 2FA is on" do
    secret = enable_2fa(users(:tech))
    post session_path, params: { email_address: "jane@example.com", password: PASSWORD }
    assert_redirected_to two_factor_session_path
    get root_path
    assert_redirected_to new_session_path, "not signed in until the code is given"
    post two_factor_session_path, params: { code: "000000" }
    assert_redirected_to two_factor_session_path
    post two_factor_session_path, params: { code: totp(secret) }
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert_select "h1", /Hi, Jane/
  end

  test "wrong password" do
    post session_path, params: { email_address: "jane@example.com", password: "nope" }
    assert_redirected_to new_session_path
    assert_match "Wrong email or password", flash[:alert]
  end

  test "supervisor without 2FA is sent to set it up" do
    sign_in_as users(:sup)
    get signatures_path
    assert_redirected_to new_two_factor_path
  end

  test "setting up 2FA" do
    sign_in_as users(:tech)
    get new_two_factor_path
    assert_response :success
    secret = session[:pending_otp_secret]
    post two_factor_path, params: { code: totp(secret) }
    assert_response :success
    assert_select "li", 10
    assert users(:tech).reload.otp_enabled?
  end

  test "invitation flow" do
    secret = enable_2fa(users(:admin))
    sign_in_as users(:admin)
    post admin_invitations_path, params: { invitation: { name: "New Tech", email_address: "new@example.com", technician: "1", supervisor: "0", admin: "0" } }
    inv = Invitation.last
    assert_redirected_to admin_invitation_path(inv)
    sign_out

    get invitation_path(inv.token)
    assert_response :success
    patch invitation_path(inv.token), params: { password: PASSWORD, password_confirmation: PASSWORD }
    assert_redirected_to root_path
    assert User.find_by(email_address: "new@example.com").technician?
    get invitation_path(inv.token)
    assert_redirected_to new_session_path, "used once"
    assert secret
  end

  test "admin pages are admin only" do
    sign_in_as users(:tech)
    get admin_users_path
    assert_response :forbidden
  end
end
