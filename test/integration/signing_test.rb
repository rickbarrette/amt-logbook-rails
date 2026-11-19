require "test_helper"

class SigningTest < ActionDispatch::IntegrationTest
  setup do
    @secret = enable_2fa(users(:sup))
    sign_in_as users(:sup)
  end

  test "queue shows entries to sign" do
    get signatures_path
    assert_response :success
    assert_select "td", /Oil change and filter inspection/
  end

  test "signs selected entries with password and authenticator code" do
    entry = work_entries(:submitted)
    post signatures_path, params: { entry_ids: [ entry.id ], certificate_id: user_certificates(:sup_ap).id, password: PASSWORD, code: totp(@secret) }
    assert_redirected_to signatures_path
    assert_match "Signed 1 entry", flash[:notice]
    assert entry.reload.signed?
    assert entry.signature.intact?
  end

  test "wrong code signs nothing" do
    entry = work_entries(:submitted)
    post signatures_path, params: { entry_ids: [ entry.id ], certificate_id: user_certificates(:sup_ap).id, password: PASSWORD, code: "000000" }
    assert_match "Nothing was signed", flash[:alert]
    assert entry.reload.submitted?
  end

  test "can't sign entries not sent to you" do
    other = work_entries(:tom_entry)
    post signatures_path, params: { entry_ids: [ other.id ], certificate_id: user_certificates(:sup_ap).id, password: PASSWORD, code: totp(@secret) }
    assert_match "Choose at least one entry", flash[:alert]
  end

  test "return an entry with a note" do
    entry = work_entries(:submitted)
    post return_entry_signature_path(entry), params: { reason: "Add the torque value" }
    assert entry.reload.returned?
    assert_equal "Add the torque value", entry.returned_reason
  end

  test "supervisor sees their technician's report and logbook" do
    get report_path(technician_id: users(:tech).id)
    assert_response :success
    get export_logbook_path(technician_id: users(:tech).id, format: :pdf)
    assert_response :success
  end

  test "but not other technicians'" do
    get report_path(technician_id: users(:other_tech).id)
    assert_response :not_found
  end
end
