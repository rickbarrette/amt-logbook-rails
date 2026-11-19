ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    PASSWORD = "correct-horse-battery".freeze

    # Turns on 2FA for a user; returns the secret.
    def enable_2fa(user)
      secret = User.new_otp_secret
      user.enable_otp!(secret)
      secret
    end

    def totp(secret) = ROTP::TOTP.new(secret).now

    def signed_entry(entry = work_entries(:submitted))
      EntrySignature.sign!(entry, by: users(:sup), certificate: user_certificates(:sup_ap))
      entry.reload
    end
  end
end
