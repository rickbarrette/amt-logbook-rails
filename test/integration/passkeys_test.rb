require "test_helper"
require "webauthn/fake_client"

# Passkeys end to end, with the webauthn gem's fake authenticator standing in
# for a phone or laptop.
class PasskeysTest < ActionDispatch::IntegrationTest
  ORIGIN = "http://www.example.com".freeze
  RP_ID = "www.example.com".freeze

  setup { @device = WebAuthn::FakeClient.new(ORIGIN) }

  def json = JSON.parse(response.body)

  # What the device stores as the account's id: the raw bytes of its handle.
  def raw_handle(user) = Base64.urlsafe_decode64(user.webauthn_handle)

  def add_passkey(name: "Test phone", password: nil)
    post options_passkeys_path, params: { name:, password: }, as: :json
    return response unless response.successful?
    credential = @device.create(challenge: json["challenge"], rp_id: RP_ID, user_verified: true)
    post passkeys_path, params: { credential: }, as: :json
    response
  end

  def passkey_assertion(options_path, user_verified: true, user: nil)
    post options_path, as: :json
    @device.get(challenge: json["challenge"], rp_id: RP_ID, user_verified:, user_handle: user && raw_handle(user))
  end

  def sign_in_with_passkey(user, **opts)
    credential = passkey_assertion(options_passkey_session_path, user:, **opts)
    post passkey_session_path, params: { credential: }, as: :json
  end

  def register_for(user)
    sign_in_as user
    add_passkey
    assert_response :success
    sign_out
  end

  test "add a passkey from the profile, then sign in with it alone" do
    user = users(:tech)
    sign_in_as user
    add_passkey(name: "Jane's iPhone")
    assert_response :success
    assert_equal [ "Jane's iPhone" ], user.passkeys.pluck(:name)
    sign_out

    sign_in_with_passkey(user)
    assert_response :success
    assert_equal "/", json["redirect"]
    get root_path
    assert_response :success
    assert user.passkeys.first.reload.last_used_at
  end

  test "an old sign-in needs the password to add a passkey" do
    user = users(:tech)
    sign_in_as user
    Current.session.update_columns(created_at: 1.hour.ago)
    add_passkey
    assert_response :forbidden
    add_passkey(password: PASSWORD)
    assert_response :success
    assert_equal 1, user.passkeys.count
  end

  test "a passkey without user verification, a replayed answer, or a disabled account is refused" do
    user = users(:tech)
    register_for(user)

    sign_in_with_passkey(user, user_verified: false)
    assert_response :unprocessable_entity

    credential = passkey_assertion(options_passkey_session_path, user:)
    post passkey_session_path, params: { credential: }, as: :json
    assert_response :success
    sign_out
    post passkey_session_path, params: { credential: }, as: :json
    assert_response :unprocessable_entity, "the challenge was used up"

    user.update!(disabled_at: Time.current)
    sign_in_with_passkey(user)
    assert_response :unprocessable_entity
  end

  test "a passkey is the second step after a password, but only the account's own" do
    jane = users(:tech)
    register_for(jane)
    tom = users(:other_tech)
    other_device = WebAuthn::FakeClient.new(ORIGIN)
    sign_in_as tom
    post options_passkeys_path, as: :json
    post passkeys_path, params: { credential: other_device.create(challenge: json["challenge"], rp_id: RP_ID, user_verified: true) }, as: :json
    sign_out

    post session_path, params: { email_address: "jane@example.com", password: PASSWORD }
    assert_redirected_to two_factor_session_path
    follow_redirect!
    assert_select "button", text: "Sign in with a passkey"
    assert_select "input[name=code]", 0, "no authenticator app, so no code box"

    post options_passkey_session_path, as: :json
    assert_equal 1, json["allowCredentials"].size, "only Jane's passkeys are offered"
    wrong = other_device.get(challenge: json["challenge"], rp_id: RP_ID, user_verified: true, user_handle: raw_handle(tom))
    post passkey_session_path, params: { credential: wrong }, as: :json
    assert_response :unprocessable_entity

    sign_in_with_passkey(jane)
    assert_response :success
    get root_path
    assert_response :success
  end

  test "a passkey works while password sign-in is locked" do
    user = users(:tech)
    register_for(user)
    user.update_columns(locked_until: 10.minutes.from_now)
    sign_in_with_passkey(user)
    assert_response :success
    assert_not user.reload.locked?
  end

  test "a passkey satisfies required two-factor" do
    admin = users(:admin)
    sign_in_as admin
    get root_path
    assert_redirected_to new_two_factor_path
    follow_redirect!
    assert_select "button", text: "Add a passkey"
    add_passkey
    get root_path
    assert_response :success
  end

  test "supervisors sign entries after confirming with a passkey, once per confirmation" do
    sup = users(:sup)
    sign_in_as sup
    add_passkey
    credential = passkey_assertion(options_passkey_confirmation_path, user: sup)
    post passkey_confirmation_path, params: { credential: }, as: :json
    assert_response :success
    get signatures_path
    assert_select "p", text: /Confirmed with your passkey/

    entry = work_entries(:submitted)
    post signatures_path, params: { entry_ids: [ entry.id ], certificate_id: user_certificates(:sup_ap).id }
    assert_equal "passkey", entry.reload.signature.auth_method
    assert entry.signature.intact?

    another = users(:tech).work_entries.create!(performed_on: Date.current - 1, minutes: 60, category: "airframe", description: "Rigged flaps", supervisor: sup, status: "submitted")
    post signatures_path, params: { entry_ids: [ another.id ], certificate_id: user_certificates(:sup_ap).id }
    assert_nil another.reload.signature, "the confirmation was used up"
  end

  test "garbage instead of a passkey answer is refused, not an error" do
    post options_passkey_session_path, as: :json
    post passkey_session_path, params: { credential: { id: "x", response: { clientDataJSON: "!!" } } }, as: :json
    assert_response :unprocessable_entity
    post passkey_session_path, params: { nothing: 1 }, as: :json
    assert_response :unprocessable_entity
  end

  test "a cloned passkey (its use counter going backwards) is refused" do
    user = users(:tech)
    register_for(user)
    user.passkeys.first.update_columns(sign_count: 1_000)
    sign_in_with_passkey(user)
    assert_response :unprocessable_entity
  end

  test "the only second factor can't be removed; an admin reset removes passkeys" do
    admin = users(:admin)
    sign_in_as admin
    add_passkey
    delete passkey_path(admin.passkeys.first)
    assert_match(/only second factor/, flash[:alert])
    assert_equal 1, admin.passkeys.count

    tech = users(:tech)
    sign_out
    register_for(tech)
    sign_in_as admin
    post reset_two_factor_admin_user_path(tech)
    assert_empty tech.passkeys
  end
end
