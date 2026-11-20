require "test_helper"

class EntriesTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:tech) }

  test "create an entry with an N-number and send it for signature" do
    RegistryRecord.create!(n_number: "777XY", manufacturer: "BEECH", model: "A36")
    assert_difference -> { WorkEntry.count } do
      post work_entries_path, params: { submit_for_signature: "1", work_entry: {
        performed_on: Date.current, hours: "3.5", category: "airframe", n_number: "n777xy", ata_chapter: "27",
        description: "Rigged aileron cables to tension chart.", supervisor_id: users(:sup).id, subject_areas: [ "", "A-I-C" ] } }
    end
    e = WorkEntry.last
    assert_redirected_to e
    assert e.submitted?
    assert_equal 210, e.minutes
    assert_equal "BEECH", e.aircraft.manufacturer
    assert_equal [ "A-I-C" ], e.subject_areas
  end

  test "the entry form has each field once" do
    get new_work_entry_path
    %w[work_entry[description] work_entry[hours] work_entry[ata_chapter] work_entry[location] work_entry[supervisor_id]].each do |name|
      assert_select "[name='#{name}']", 1, name
    end
    assert_select "input[name='work_entry[category]']", Faa.categories.size
    Setting.set("signature_mode", "ink")
    get new_work_entry_path
    assert_select "[name='work_entry[description]']", 1
    assert_select "[name='work_entry[supervisor_name]']", 1
    assert_select "[name='work_entry[supervisor_id]']", 0
  end

  test "invalid entry re-renders the form" do
    post work_entries_path, params: { work_entry: { performed_on: Date.current, hours: "", category: "airframe", description: "" } }
    assert_response :unprocessable_entity
  end

  test "can't see another technician's entry" do
    get work_entry_path(work_entries(:tom_entry))
    assert_response :not_found
  end

  test "can't edit a signed entry" do
    entry = signed_entry
    get edit_work_entry_path(entry)
    assert_redirected_to entry
    patch work_entry_path(entry), params: { work_entry: { description: "changed" } }
    assert_redirected_to entry
    assert_not_equal "changed", entry.reload.description
  end

  test "dashboard, list, reports and aircraft pages render" do
    signed_entry
    [ root_path, work_entries_path, work_entries_path(status: "signed"), report_path, timers_path, aircraft_index_path,
      aircraft_path(aircraft(:n12345)), logbook_path, profile_path, new_work_entry_path, work_entry_path(work_entries(:submitted)) ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "N-number lookup" do
    RegistryRecord.create!(n_number: "4242", manufacturer: "PIPER", model: "J-3")
    get lookup_aircraft_index_path(n_number: "N4242"), as: :json
    assert response.parsed_body["found"]
    assert_match "PIPER J-3", response.parsed_body["description"]
    get lookup_aircraft_index_path(n_number: "N1"), as: :json
    assert_not response.parsed_body["found"]
  end

  test "timer: clock in, close the app, clock out into a draft entry" do
    travel_to Time.zone.local(2026, 11, 2, 7, 0, 0)
    post timers_path, params: { n_number: "N12345", category: "powerplant", description: "Compression test" }
    timer = users(:tech).running_timer
    assert timer
    travel 3.hours
    get root_path
    assert_select "[data-controller=clock]"
    post stop_timer_path(timer)
    entry = timer.reload.work_entry
    assert_redirected_to edit_work_entry_path(entry)
    assert_equal 180, entry.minutes
    assert_equal "Compression test", entry.description
  end

  test "timer: fill in the entry while the clock runs, then clock out and send it" do
    travel_to Time.zone.local(2026, 11, 2, 7, 0, 0)
    post timers_path, params: { n_number: "N12345", description: "Brakes", fill_in: "1" }
    entry = users(:tech).running_timer.work_entry
    assert_redirected_to edit_work_entry_path(entry)
    follow_redirect!
    assert_select "[data-controller=clock]"
    assert_select "input[name='work_entry[hours]']", 0
    assert_select "input[name=submit_for_signature]", 0

    travel 1.hour
    patch work_entry_path(entry), params: { work_entry: { description: "Replaced left brake linings", hours: "9", category: "airframe",
                                                          ata_chapter: "32", supervisor_id: users(:sup).id }, submit_for_signature: "1" }
    assert_redirected_to work_entry_path(entry)
    entry.reload
    assert entry.draft?, "not sent while the clock runs"
    assert_equal "Replaced left brake linings", entry.description
    assert_not_equal 540, entry.minutes, "the timer owns the hours"
    get work_entries_path
    assert_select "td", text: /running/

    post submit_work_entry_path(entry)
    assert_match(/Clock out first/, flash[:alert])

    travel 30.minutes
    post stop_timer_path(entry.timer)
    assert_equal 90, entry.reload.minutes
    post submit_work_entry_path(entry)
    assert entry.reload.submitted?
  end

  test "previous and next entries, by date, within one technician's logbook" do
    tech = users(:tech)
    a = tech.work_entries.create!(performed_on: Date.current - 30, minutes: 60, category: "general", description: "First")
    b = tech.work_entries.create!(performed_on: Date.current - 29, minutes: 60, category: "general", description: "Second")
    c = tech.work_entries.create!(performed_on: Date.current - 29, minutes: 60, category: "general", description: "Same day, added later")
    users(:other_tech).work_entries.create!(performed_on: Date.current - 29, minutes: 60, category: "general", description: "Tom's")
    assert_equal [ a, c ], [ b.previous_entry, b.next_entry ]
    assert_equal b, c.previous_entry
    sign_in_as tech
    get work_entry_path(b)
    assert_select "a[rel=prev][href=?]", work_entry_path(a)
    assert_select "a[rel=next][href=?]", work_entry_path(c)
    first = tech.work_entries.order(:performed_on, :id).first
    get work_entry_path(first)
    assert_select "a[rel=prev]", 0
  end

  test "printable logbook PDF and CSV" do
    signed_entry
    get export_logbook_path(format: :pdf, include_unsigned: "1")
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
    text = PDF::Inspector::Text.analyze(response.body).strings.join(" ") if defined?(PDF::Inspector)
    assert_match(/Sam Supervisor/, text) if text

    get export_logbook_path(format: :csv)
    assert_response :success
    assert_match "Oil change and filter inspection", response.body
    assert_no_match "Replaced left main brake", response.body, "unsigned entries left out by default"
  end

  test "many entries paginate across PDF pages" do
    40.times do |i|
      users(:tech).work_entries.create!(performed_on: Date.current - i, minutes: 120, category: "general",
                                        description: "Long description of work performed " * (i % 5 + 1), supervisor: users(:sup)).submit!
    end
    get export_logbook_path(format: :pdf, include_unsigned: "1")
    assert_response :success
    assert response.body.start_with?("%PDF")
  end
end
