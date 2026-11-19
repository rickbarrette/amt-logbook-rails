require "test_helper"

class EntryFormHelpersTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup { sign_in_as users(:tech) }

  test "suggests category, chapter and areas from a description" do
    get suggestions_entry_path(text: "Rigged aileron cables to tension chart")
    body = response.parsed_body
    assert body["found"]
    assert_equal "27", body["ata_chapter"]
    assert_equal "airframe", body["category"]
    assert body["subject_areas"].any? { _1["code"] == "A-I-C" }
  end

  test "location suggestions: history first, then airports" do
    Airport.create!(ident: "KPVD", code: "KPVD", name: "T. F. Green", kind: "large_airport", municipality: "Providence", region: "US-RI")
    work_entries(:draft).update!(location: "KPVD")
    get suggestions_locations_path
    assert_equal "KPVD", response.parsed_body.first["value"]
    assert response.parsed_body.first["history"]
    get suggestions_locations_path(q: "provid")
    assert_equal "KPVD", response.parsed_body.first["value"]
  end

  test "aircraft suggestions: worked on before, then the registry" do
    RegistryRecord.create!(n_number: "12399", manufacturer: "PIPER", model: "PA-18")
    get suggestions_aircraft_path
    assert_equal "N12345", response.parsed_body.first["value"]
    get suggestions_aircraft_path(q: "N123")
    values = response.parsed_body.map { _1["value"] }
    assert_equal %w[N12345 N12399], values
  end

  test "markdown preview is rendered and sanitized" do
    post markdown_preview_path, params: { text: "- **torqued**\n<script>alert(1)</script>" }
    assert_includes response.body, "<strong>torqued</strong>"
    assert_not_includes response.body, "<script>"
  end

  test "entries show markdown" do
    work_entries(:draft).update!(description: "- **Replaced** brake linings")
    get work_entry_path(work_entries(:draft))
    assert_select ".prose-notes li strong", "Replaced"
  end

  test "save and add another carries the day, aircraft and place" do
    post work_entries_path, params: { add_another: "1", work_entry: {
      performed_on: Date.current - 1, hours: "2", category: "airframe", n_number: "N12345", location: "KPVD",
      description: "First task", supervisor_id: users(:sup).id } }
    first = WorkEntry.last
    assert first.submitted?, "does what the primary button does"
    assert_redirected_to new_work_entry_path(from: first.id)
    follow_redirect!
    assert_select "input[name='work_entry[n_number]'][value='N12345']"
    assert_select "input[name='work_entry[location]'][value='KPVD']"
    assert_select "input[name='work_entry[performed_on]'][value='#{Date.current - 1}']"
    assert_select "textarea[name='work_entry[description]']", text: ""
  end

  test "admin airports page" do
    enable_2fa(users(:admin))
    sign_in_as users(:admin)
    get admin_airports_path
    assert_response :success
    assert_enqueued_jobs(1, only: AirportUpdateJob) { post admin_airports_path }
  end
end
