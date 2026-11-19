require "test_helper"

class InkSignaturesTest < ActionDispatch::IntegrationTest
  setup do
    Setting.set("signature_mode", "ink")
    sign_in_as users(:tech)
  end

  test "entries are recorded with a typed supervisor and count toward the requirement" do
    users(:tech).work_entries.delete_all
    post work_entries_path, params: { submit_for_signature: "1", work_entry: {
      performed_on: Date.current, hours: "4", category: "airframe", description: "Rigged flaps.",
      supervisor_name: "Pat Inkwell", supervisor_certificate: "A&P 7654321" } }
    e = WorkEntry.last
    assert e.recorded?
    assert_equal "Pat Inkwell", e.supervisor_display_name
    assert_equal 4.0, ExperienceReport.new(users(:tech)).qualifying_hours
    assert_equal "Pat Inkwell", ExperienceReport.new(users(:tech)).signers.sole[:name]
  end

  test "the signing queue is off and supervisors don't need 2FA" do
    sign_in_as users(:sup)
    get signatures_path
    assert_redirected_to root_path
    get root_path
    assert_response :success
  end

  test "printed logbook in ink mode" do
    work_entries(:draft).update!(supervisor_name: "Pat Inkwell", supervisor_certificate: "A&P 7654321")
    work_entries(:draft).record!
    get export_logbook_path(format: :pdf)
    assert_response :success
    assert response.body.start_with?("%PDF")
    get export_logbook_path(format: :csv)
    assert_match "Pat Inkwell", response.body
  end

  test "new entry form offers supervisor name fields" do
    get new_work_entry_path
    assert_select "input[name='work_entry[supervisor_name]']"
    assert_select "input[value='Save and record']"
  end
end
