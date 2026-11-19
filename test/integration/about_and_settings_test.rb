require "test_helper"

class AboutAndSettingsTest < ActionDispatch::IntegrationTest
  test "about page for a user: version and release notes, no system details" do
    sign_in_as users(:tech)
    get about_path
    assert_response :success
    assert_select "p.font-mono", Rails.application.config.x.version
    assert_select "#releases details"
    assert_select "h2", text: "Configuration", count: 0
  end

  test "admin sees system details and changes the signature mode" do
    enable_2fa(users(:admin))
    sign_in_as users(:admin)
    get about_path
    assert_select "h2", "Configuration"
    patch admin_settings_path, params: { signature_mode: "ink" }
    assert Setting.ink_signatures?
    get admin_settings_path
    assert_response :success
  end

  test "changelog parses releases" do
    log = Changelog.new("# What's new\n\n## 2026.11.1\n\n### Changes\n- A\n\n## 2026.11.0\n\n- B\n")
    assert_equal %w[2026.11.1 2026.11.0], log.releases.map(&:version)
    assert_match "- A", log.release("2026.11.1").markdown
  end
end
