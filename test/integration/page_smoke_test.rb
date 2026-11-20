require "test_helper"

# Every page renders for each kind of account, with a sign-in that's an hour
# old: some parts of pages (like asking for the password before adding a
# passkey) only appear for older sign-ins, and fresh test sign-ins skip them.
class PageSmokeTest < ActionDispatch::IntegrationTest
  PAGES = {
    tech: %w[/ /work_entries /work_entries/new /timers /report /logbook /aircraft /imports /profile /about],
    sup: %w[/ /signatures /profile /about],
    admin: %w[/ /admin/users /admin/settings /admin/registry_imports /admin/airports /admin/backup /admin/invitations/new /profile /about]
  }.freeze

  PAGES.each do |who, paths|
    test "#{who}: every page renders for an hour-old sign-in" do
      user = users(who)
      enable_2fa(user) if user.otp_required?
      sign_in_as user
      Current.session.update_columns(created_at: 1.hour.ago)
      paths.each do |path|
        get path
        assert_response :success, "#{path} for #{who}"
      end
      get work_entry_path(work_entries(:draft)) if who == :tech
      get aircraft_path(aircraft(:n12345)) if who == :tech
      get edit_admin_user_path(users(:tech)) if who == :admin
      assert_response :success
    end
  end
end
