require "test_helper"

class ImportExportTest < ActionDispatch::IntegrationTest
  def upload(content, name: "entries.csv", type: "text/csv")
    file = Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: name)
    post imports_path, params: { file: }
  end

  test "upload a CSV, fix the column matching, import, and send everything to the supervisor" do
    sign_in_as users(:tech)
    upload "When,Length,What\n2026-11-03,1.5,Replaced left nav light bulb\n2026-11-04,1,Swung compass\n"
    import = EntryImport.last
    assert_redirected_to import_path(import)
    follow_redirect!
    assert_select "select[name='mapping[performed_on]']"

    patch import_path(import), params: { mapping: { performed_on: "0", description: "2" }, import: "1" }
    assert_redirected_to import_path(import)
    assert_match(/Choose the column for hours/, flash[:alert])

    patch import_path(import), params: { mapping: { performed_on: "0", hours: "1", description: "2" } }
    follow_redirect!
    assert_select "td", text: /Replaced left nav light bulb/

    patch import_path(import), params: { mapping: { performed_on: "0", hours: "1", description: "2" }, import: "1" }
    assert_equal 2, import.reload.created_count
    assert_equal %w[33 34], import.work_entries.order(:performed_on).pluck(:ata_chapter)

    post finish_import_path(import), params: { supervisor_id: users(:sup).id }
    assert_equal %w[submitted submitted], import.work_entries.pluck(:status)
    assert_equal [ users(:sup).id ], import.work_entries.pluck(:supervisor_id).uniq
  end

  test "ink mode records imported drafts in one go" do
    Setting.set("signature_mode", "ink")
    sign_in_as users(:tech)
    upload "Date,Hours,Description\n2026-11-03,1,Replaced strobe\n"
    import = EntryImport.last
    patch import_path(import), params: { mapping: { performed_on: "0", hours: "1", description: "2" }, import: "1" }
    post finish_import_path(import)
    assert_equal %w[recorded], import.work_entries.pluck(:status)
  end

  test "spreadsheet files and bad exports are refused with a helpful message" do
    sign_in_as users(:tech)
    upload "PK\x03\x04", name: "log.xlsx"
    assert_match(/Save the spreadsheet as CSV/, flash[:alert])
    upload '{"format":"something-else"}', name: "x.json", type: "application/json"
    assert_match(/isn't an AMT Logbook export/, flash[:alert])
    assert_equal 0, EntryImport.count
  end

  test "imports are private" do
    import = users(:tech).entry_imports.create!(kind: "csv", data: "Date,Hours,Description\n")
    sign_in_as users(:other_tech)
    get import_path(import)
    assert_response :not_found
  end

  test "full export downloads as JSON and filters narrow the CSV" do
    sign_in_as users(:tech)
    get export_logbook_path(format: :json)
    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal users(:tech).work_entries.count, JSON.parse(response.body)["entries"].size

    get export_logbook_path(format: :csv, entries: "all", category: "airframe")
    rows = CSV.parse(response.body, headers: true)
    assert_equal users(:tech).work_entries.where(category: "airframe").count, rows.size
    assert rows.all? { _1["Category"] == "Airframe" }

    get export_logbook_path(format: :csv)
    assert_equal users(:tech).work_entries.signed.count, CSV.parse(response.body, headers: true).size
  end

  test "an admin downloads a backup after confirming who they are" do
    admin = users(:admin)
    secret = enable_2fa(admin)
    sign_in_as admin
    get admin_backup_path
    assert_response :success

    post admin_backup_path, params: { password: "wrong", code: totp(secret) }
    assert_redirected_to admin_backup_path

    post admin_backup_path, params: { password: PASSWORD, code: totp(secret) }
    assert_response :success
    assert_match(/attachment; filename="amt-logbook-backup-/, response.headers["Content-Disposition"])
    path = Rails.root.join("tmp/test-backup-#{Process.pid}.sqlite3")
    File.binwrite(path, response.body)
    db = SQLite3::Database.new(path.to_s)
    assert_equal User.count, db.get_first_value("SELECT COUNT(*) FROM users")
    assert_equal 0, db.get_first_value("SELECT COUNT(*) FROM sessions")
  ensure
    db&.close
    FileUtils.rm_f(path) if path
  end

  test "only admins see the backup page" do
    sign_in_as users(:tech)
    get admin_backup_path
    assert_response :forbidden
  end
end
