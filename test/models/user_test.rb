require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "authenticator codes work once, recovery codes work once" do
    user = users(:tech)
    secret = User.new_otp_secret
    codes = user.enable_otp!(secret)
    code = totp(secret)
    assert user.verify_second_factor(code)
    assert_not user.verify_second_factor(code), "a code can't be replayed"
    assert user.verify_second_factor(codes.first)
    assert_not user.verify_second_factor(codes.first)
    assert_equal 9, user.recovery_codes_left
  end

  test "locks after repeated failed sign-ins" do
    User::LOCK_AFTER.times { User.authenticate_with_lockout(email_address: "jane@example.com", password: "wrong") }
    assert users(:tech).reload.locked?
    assert_nil User.authenticate_with_lockout(email_address: "jane@example.com", password: PASSWORD)
  end

  test "supervisors and admins need two-factor" do
    assert users(:sup).otp_required?
    assert users(:admin).otp_required?
    assert_not users(:tech).otp_required?
  end
end
