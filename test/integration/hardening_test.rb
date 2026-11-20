require "test_helper"

# Protections for running with the sign-in page on the open internet.
class HardeningTest < ActionDispatch::IntegrationTest
  test "codes and the setup code are kept out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("code" => "123456", "setup_code" => "ABCDEFGHIJ", "password" => "x", "name" => "Jane")
    assert_equal "[FILTERED]", filtered["code"]
    assert_equal "[FILTERED]", filtered["setup_code"]
    assert_equal "Jane", filtered["name"]
  end

  test "pages carry a strict Content-Security-Policy with a script nonce" do
    sign_in_as users(:tech)
    get report_path
    csp = response.headers["Content-Security-Policy"]
    assert_match(/script-src 'self' 'nonce-/, csp)
    assert_match(/frame-ancestors 'none'/, csp)
    assert_match(/object-src 'none'/, csp)
    assert_match(/form-action 'self'/, csp)
    nonce = csp[/'nonce-([^']+)'/, 1]
    assert_select "script[type=importmap][nonce=?]", nonce
    assert_select "script:not([nonce])", 0, "every inline script carries the nonce"
  end

  test "only people who logged work on an aircraft, or admins, can change it" do
    plane = aircraft(:n12345)
    sign_in_as users(:other_tech) # has no entries on it
    patch aircraft_path(plane), params: { aircraft: { model: "Hijacked" } }
    assert_redirected_to aircraft_path(plane)
    assert_not_equal "Hijacked", plane.reload.model
    post refresh_aircraft_path(plane)
    assert_redirected_to aircraft_path(plane)
    assert_match(/Only people who've logged work/, flash[:alert])

    sign_in_as users(:tech) # logged work on it
    patch aircraft_path(plane), params: { aircraft: { model: "172S" } }
    assert_equal "172S", plane.reload.model
  end

  test "changing an aircraft's details doesn't make signed entries look altered" do
    entry = signed_entry
    assert entry.signature.intact?
    entry.aircraft.update!(manufacturer: "CESSNA", model: "172S Skyhawk SP", year_manufactured: 2001)
    assert entry.reload.signature.intact?, "registry refreshes and aircraft edits aren't tampering"
    entry.update_column(:description, "Changed after signing")
    assert_not entry.reload.signature.intact?, "changing what was signed still shows"
  end

  test "password reset: case-insensitive email, blank refused, lockout lifted, all devices signed out" do
    user = users(:tech)
    user.update_columns(failed_sign_ins: 0, locked_until: 10.minutes.from_now)
    assert_enqueued_emails 1 do
      post passwords_path, params: { email_address: "  JANE@Example.com " }
    end
    token = user.password_reset_token
    put password_path(token), params: { password: "", password_confirmation: "" }
    assert_match(/Choose a new password/, flash[:alert])
    user.sessions.create!
    put password_path(token), params: { password: "brand-new-password-1", password_confirmation: "brand-new-password-1" }
    assert_redirected_to new_session_path
    user.reload
    assert_not user.locked?
    assert_empty user.sessions
    assert user.authenticate("brand-new-password-1")
  end

  test "disabled accounts get no reset email" do
    users(:tech).update!(disabled_at: Time.current)
    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: "jane@example.com" }
    end
  end

  test "an admin can make a reset link to send by hand" do
    admin = users(:admin)
    enable_2fa(admin)
    sign_in_as admin
    post password_reset_link_admin_user_path(users(:tech))
    assert_response :success
    link = css_select("input[readonly]").first["value"]
    assert_match %r{/passwords/.+/edit}, link
    sign_out
    get URI(link).path
    assert_response :success
  end

  test "two-factor for everyone sends technicians to set it up" do
    Setting.set("require_two_factor", "everyone")
    sign_in_as users(:tech)
    get root_path
    assert_redirected_to new_two_factor_path
  end

  test "sign out every other device" do
    user = users(:tech)
    sign_in_as user
    user.sessions.create!
    user.sessions.create!
    delete other_sessions_profile_path
    assert_equal 1, user.sessions.count
    get root_path
    assert_response :success, "this device stays signed in"
  end

  test "a sign-in ends 90 days after it started, even if used every day" do
    sign_in_as users(:tech)
    Current.session.update_columns(created_at: 91.days.ago, updated_at: 1.hour.ago)
    get root_path
    assert_redirected_to new_session_path
  end
end
