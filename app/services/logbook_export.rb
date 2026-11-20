# A technician's complete logbook as one JSON file: entries (with Markdown
# descriptions), aircraft, supervisors, e-signature records with their seals
# and content snapshots, and certificates. It's for keeping a copy, moving to
# another server, or reading with other tools; Import reads it back.
class LogbookExport
  FORMAT = "amt-logbook-export".freeze
  VERSION = 1

  def initialize(technician, entries = nil)
    @technician = technician
    @entries = entries || technician.work_entries
  end

  def filename = "amt-logbook-#{@technician.name.parameterize}-#{Date.current.iso8601}.json"

  def to_json(*) = JSON.pretty_generate(as_json)

  def as_json(*)
    {
      format: FORMAT, version: VERSION, exported_at: Time.current.iso8601,
      app: { name: "AMT Logbook", version: Rails.application.config.x.version, revision: Rails.application.config.x.app_revision },
      technician: { name: @technician.name, rating_goal: @technician.rating_goal,
                    experience_started_on: @technician.experience_started_on&.iso8601 },
      certificates: @technician.certificates.map { { kind: _1.kind, number: _1.number, expires_on: _1.expires_on&.iso8601 } },
      entries: @entries.includes(:aircraft, :supervisor, :signature).chronological.map { entry_json(_1) }
    }
  end

  private

  def entry_json(e)
    {
      performed_on: e.performed_on.iso8601, minutes: e.minutes, hours: e.hours,
      started_at: e.started_at&.iso8601, ended_at: e.ended_at&.iso8601,
      category: e.category, ata_chapter: e.ata_chapter.presence, subject_areas: e.subject_areas,
      description: e.description, reference: e.reference, location: e.location, status: e.status,
      aircraft: e.aircraft && aircraft_json(e.aircraft),
      supervisor: { name: e.supervisor_display_name, certificate: e.supervisor_display_certificate }.compact.presence,
      returned_reason: e.returned_reason, signature: e.signature && signature_json(e.signature),
      imported: e.import_details.presence
    }.compact
  end

  def aircraft_json(a)
    { n_number: a.n_number, year_manufactured: a.year_manufactured, manufacturer: a.manufacturer, model: a.model,
      serial_number: a.serial_number }.compact
  end

  def signature_json(s)
    { signer_name: s.signer_name, certificate_kind: s.certificate_kind, certificate_number: s.certificate_number,
      statement: s.statement, signed_at: s.signed_at.iso8601(6), auth_method: s.auth_method,
      content_digest: s.content_digest, content_snapshot: JSON.parse(s.content_snapshot), seal: s.seal,
      intact: s.intact? }
  end
end
