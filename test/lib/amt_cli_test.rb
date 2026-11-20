require "test_helper"

class AmtCliTest < ActiveSupport::TestCase
  # Runs `bin/amt ARGS`; returns [stdout, stderr, exit status].
  def amt(*args)
    status = 0
    out, err = capture_io do
      AmtCli.start(args.map(&:to_s))
    rescue SystemExit => e
      status = e.status
    end
    [ out, err, status ]
  end

  test "status and users" do
    out, _, status = amt("status")
    assert_equal 0, status
    assert_match(/Users\s+4/, out)
    out, = amt("users")
    assert_match(/jane@example\.com\s+Jane Tech\s+technician/, out)
  end

  test "a reset link and an invitation link work in the browser" do
    out, = amt("reset-password", "JANE@example.com")
    token = out[%r{/passwords/([^/\s]+)/edit}, 1]
    assert_equal users(:tech), User.find_by_password_reset_token(token)

    out, = amt("invite", "new@example.com", "New Person", "--supervisor", "--no-technician")
    invitation = Invitation.find_usable(out[%r{/invitations/(\S+)}, 1])
    assert invitation.supervisor?
    assert_not invitation.technician?
  end

  test "lost phone: reset two-factor removes the authenticator and passkeys and signs out" do
    user = users(:sup)
    enable_2fa(user)
    user.passkeys.create!(external_id: "abc", public_key: "key", name: "Phone")
    user.sessions.create!
    amt("reset-2fa", user.email_address, "--yes")
    user.reload
    assert_not user.second_factor?
    assert_empty user.sessions
  end

  test "unlock, disable, enable, make-admin, sign-out" do
    user = users(:tech)
    user.update_columns(locked_until: 1.hour.from_now, failed_sign_ins: 10)
    amt("unlock", user.email_address)
    assert_not user.reload.locked?

    user.sessions.create!
    amt("disable", user.email_address, "-y")
    assert user.reload.disabled?
    assert_empty user.sessions
    amt("enable", user.email_address)
    assert_not user.reload.disabled?

    amt("make-admin", user.email_address)
    assert user.reload.admin?
    amt("make-admin", user.email_address, "--off")
    assert_not user.reload.admin?
  end

  test "the last admin can't be disabled or demoted; mistakes exit with 1" do
    _, err, status = amt("disable", "admin@example.com", "-y")
    assert_equal 1, status
    assert_match(/only active admin/, err)
    assert_not users(:admin).reload.disabled?

    _, _, status = amt("make-admin", "admin@example.com", "--off")
    assert_equal 1, status
    assert users(:admin).reload.admin?

    _, err, status = amt("unlock", "nobody@example.com")
    assert_equal 1, status
    assert_match(/No account/, err)
  end

  test "settings show and change, with only known values" do
    out, = amt("settings")
    assert_match(/require_two_factor\s+staff/, out)
    amt("settings", "require_two_factor", "everyone")
    assert Setting.two_factor_for_everyone?
    _, _, status = amt("settings", "signature_mode", "crayon")
    assert_equal 1, status
  end

  test "setup code only before the first admin exists" do
    _, _, status = amt("setup-code")
    assert_equal 1, status
  end

  test "verify-signatures reports tampering and exits with 1" do
    entry = signed_entry
    out, _, status = amt("verify-signatures")
    assert_equal 0, status
    assert_match(/1 signatures checked, 1 intact/, out)
    entry.update_column(:description, "Changed after signing")
    out, _, status = amt("verify-signatures")
    assert_equal 1, status
    assert_match(/entry changed after signing/, out)
  end

  test "backup and export write files" do
    Dir.mktmpdir do |dir|
      amt("backup", "#{dir}/backup.sqlite3")
      db = SQLite3::Database.new("#{dir}/backup.sqlite3")
      assert_equal User.count, db.get_first_value("SELECT COUNT(*) FROM users")
      db.close

      amt("export", "jane@example.com", "--out", "#{dir}/jane.json")
      assert_equal "amt-logbook-export", JSON.parse(File.read("#{dir}/jane.json"))["format"]
      amt("export", "jane@example.com", "--format", "csv", "--out", "#{dir}/jane.csv")
      assert_match(/\ADate,N-number/, File.read("#{dir}/jane.csv"))
    end
  end
end
