require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup do
    enable_2fa(users(:admin))
    sign_in_as users(:admin)
  end

  test "users page and linking a supervisor" do
    get admin_users_path
    assert_response :success
    post admin_user_supervisions_path(users(:other_tech)), params: { supervisor_id: users(:sup).id }
    assert users(:other_tech).supervisors.include?(users(:sup))
  end

  test "disable a user signs them out" do
    users(:tech).sessions.create!
    post disable_admin_user_path(users(:tech))
    assert users(:tech).reload.disabled?
    assert_empty users(:tech).sessions
  end

  test "registry upload queues an import" do
    file = Rack::Test::UploadedFile.new(StringIO.new("N-NUMBER,SERIAL NUMBER\n1,2\n"), "text/plain", original_filename: "MASTER.txt")
    assert_enqueued_with(job: RegistryImportJob) do
      post admin_registry_imports_path, params: { file: file }
    end
    assert_redirected_to admin_registry_imports_path
    get admin_registry_imports_path
    assert_response :success
  end
end
