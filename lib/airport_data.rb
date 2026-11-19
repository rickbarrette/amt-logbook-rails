require "csv"
require "open-uri"

# Keeps the airports table in sync with OurAirports
# (https://ourairports.com/data/, public domain), as SAM does: populated on
# first start (AirportUpdateJob, queued at boot), refreshed by an admin.
# New airports are added, changed ones updated, removed ones deleted.
#
# Each airport's code is the 4-character GPS code when it doesn't collide
# with another airport's identifier, otherwise the OurAirports identifier
# (so US airports read KPVD, K1B9…).
module AirportData
  SOURCE_URL = "https://davidmegginson.github.io/ourairports-data/airports.csv".freeze
  BATCH = 2_000
  FIELDS = %i[code gps_code local_code iata name kind municipality region country latitude longitude].freeze

  module_function

  def refresh!(url = SOURCE_URL)
    Tempfile.create([ "airports", ".csv" ], binmode: true) do |file|
      URI.parse(url).open(read_timeout: 300, open_timeout: 30) { |remote| IO.copy_stream(remote, file) }
      file.flush
      sync!(file.path)
    end
  end

  # Sync from a CSV path in OurAirports' format. Returns { created:, updated:, removed: }.
  def sync!(path)
    rows = CSV.read(path, headers: true, encoding: "bom|utf-8").map(&:to_h)
    idents = rows.to_set { _1["ident"].to_s.strip.upcase }
    now = Time.current
    incoming = rows.filter_map { build(_1, idents) }.index_by { _1[:ident] }
    existing = Airport.pluck(:id, :ident, *FIELDS).to_h { |id, ident, *values| [ ident, [ id, FIELDS.zip(values).to_h ] ] }

    created = incoming.except(*existing.keys).values
    changed = incoming.slice(*existing.keys).filter_map do |ident, rec|
      id, current = existing[ident]
      rec.slice(*FIELDS).merge(id:, ident:) if normalize(current) != normalize(rec.slice(*FIELDS))
    end
    stale = existing.keys - incoming.keys

    Airport.transaction do
      created.each_slice(BATCH) { |b| Airport.insert_all(b.map { _1.merge(created_at: now, updated_at: now) }) }
      changed.each_slice(BATCH) { |b| Airport.upsert_all(b.map { _1.merge(created_at: now, updated_at: now) }, unique_by: :id, update_only: FIELDS + [ :updated_at ]) }
      stale.each_slice(BATCH) { |b| Airport.where(ident: b).delete_all }
    end
    { created: created.size, updated: changed.size, removed: stale.size }
  end

  def build(row, idents)
    ident = row["ident"].to_s.strip.upcase
    return if ident.empty?
    gps = row["gps_code"].to_s.strip.upcase.presence
    { ident:, code: gps && gps.length == 4 && (!idents.include?(gps) || gps == ident) ? gps : ident, gps_code: gps,
      local_code: row["local_code"].to_s.strip.upcase.presence, iata: row["iata_code"].to_s.strip.upcase.presence,
      name: row["name"].to_s.strip.presence || ident, kind: row["type"].to_s.presence,
      municipality: row["municipality"].to_s.strip.presence, region: row["iso_region"].to_s.presence,
      country: row["iso_country"].to_s.presence, latitude: row["latitude_deg"].presence&.to_f,
      longitude: row["longitude_deg"].presence&.to_f }
  end

  def normalize(attrs) = attrs.transform_values { _1.is_a?(Float) ? _1.round(6) : _1 }
end
