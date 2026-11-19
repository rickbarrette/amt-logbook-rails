# Demo data for development: bin/rails db:seed
# Everyone's password is "demo-password-123". Dummy names and tail numbers only.
return unless Rails.env.development?

password = "demo-password-123"
admin = User.find_or_create_by!(email_address: "admin@example.com") { |u| u.assign_attributes(name: "Alex Admin", password:, admin: true, technician: false) }
sup = User.find_or_create_by!(email_address: "sam@example.com") { |u| u.assign_attributes(name: "Sam Supervisor", password:, supervisor: true, technician: false) }
sup2 = User.find_or_create_by!(email_address: "pat@example.com") { |u| u.assign_attributes(name: "Pat Powerplant", password:, supervisor: true, technician: false) }
tech = User.find_or_create_by!(email_address: "jane@example.com") { |u| u.assign_attributes(name: "Jane Tech", password:, rating_goal: "both") }
sup.certificates.find_or_create_by!(kind: "AP", number: "1234567")
sup2.certificates.find_or_create_by!(kind: "P", number: "7654321")
[ sup, sup2 ].each { |s| Supervision.find_or_create_by!(technician: tech, supervisor: s) }

[ { n_number: "N12345", manufacturer: "CESSNA", model: "172S", year_manufactured: 2001, aircraft_type: "Fixed wing single engine" },
  { n_number: "N54321", manufacturer: "PIPER", model: "PA-28-181", year_manufactured: 1979, aircraft_type: "Fixed wing single engine" },
  { n_number: "N777XY", manufacturer: "BEECH", model: "A36", year_manufactured: 1995, aircraft_type: "Fixed wing single engine" } ]
  .each { |a| Aircraft.find_or_create_by!(n_number: a[:n_number]) { _1.assign_attributes(a) } }

if tech.work_entries.none?
  tasks = [
    [ "airframe", "32", %w[A-II-A], "Removed and replaced left main brake linings per maintenance manual 32-40-00. Ops checked." ],
    [ "airframe", "27", %w[A-I-C], "Inspected aileron cables for wear and tension; adjusted to tension chart." ],
    [ "powerplant", "79", %w[P-II-D], "Changed oil and filter, cut filter for inspection, safety wired." ],
    [ "powerplant", "74", %w[P-II-E], "Removed, cleaned, gapped and rotated spark plugs; timing check of magnetos." ],
    [ "general", "12", %w[G-F G-G], "Serviced tires and struts; washed aircraft and treated corrosion on belly skins." ],
    [ "airframe", "57", %w[A-I-A G-E], "Repaired wing inspection panel crack with doubler per AC 43.13-1B." ],
    [ "powerplant", "61", %w[P-II-J], "Dressed propeller leading edge nicks and checked track." ],
    [ "general", "08", %w[G-C], "Weighed aircraft and computed new empty weight and CG." ]
  ]
  start = Date.current - 150
  (0...150).step(2).each_with_index do |d, i|
    cat, ata, areas, desc = tasks[i % tasks.size]
    supervisor = cat == "powerplant" && i.even? ? sup2 : sup
    e = tech.work_entries.create!(performed_on: start + d, minutes: [ 360, 420, 480, 510 ][i % 4], category: cat, ata_chapter: ata,
                                  subject_areas: areas, description: desc, aircraft: Aircraft.all.sample, supervisor:)
    next if d > 140
    e.submit!
    next if d > 130
    EntrySignature.sign!(e, by: supervisor, certificate: supervisor.certificates.first)
  end
end
puts "Seeded. Sign in as jane@example.com / admin@example.com / sam@example.com with #{password}"
