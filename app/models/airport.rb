# Airport reference data from OurAirports; see lib/airport_data.rb.
class Airport < ApplicationRecord
  KIND_RANK = { "large_airport" => 0, "medium_airport" => 1, "small_airport" => 2, "seaplane_base" => 3,
                "heliport" => 4, "balloonport" => 5, "closed" => 9 }.freeze

  def place = [ municipality, region.to_s.split("-", 2).last.presence ].compact.join(", ")
  def other_codes = [ local_code, gps_code, iata ].compact.uniq - [ code ]
  def label = "#{code} · #{name}"

  def as_suggestion
    { value: code, label: name, detail: [ place, (other_codes.any? ? "also #{other_codes.join(", ")}" : nil) ].compact_blank.join(" · ") }
  end

  # Best match for a code in any code system (KPVD, PVD, 1B9…).
  def self.lookup(code)
    c = code.to_s.strip.upcase
    return if c.empty?
    where(code: c).or(where(ident: c)).or(where(gps_code: c)).or(where(local_code: c)).or(where(iata: c))
      .min_by { [ _1.kind == "closed" ? 1 : 0, _1.code == c ? 0 : 1, KIND_RANK.fetch(_1.kind, 8) ] }
  end

  # Autocomplete: exact codes, then code prefixes, then name/town matches.
  def self.search(query, limit: 8)
    q = query.to_s.strip
    return [] if q.length < 2
    up = q.upcase
    exact = where(code: up).or(where(ident: up)).or(where(gps_code: up)).or(where(local_code: up)).or(where(iata: up)).to_a
    prefix = up.match?(/\A[A-Z0-9]{2,4}\z/) ? where("code LIKE :p OR local_code LIKE :p", p: "#{sanitize_sql_like(up)}%").limit(100).to_a : []
    named = where("name LIKE :q OR municipality LIKE :q", q: "%#{sanitize_sql_like(q)}%").limit(200).to_a
    # US airports first (FAA mechanics), then by size.
    rank = ->(a) { [ a.kind == "closed" ? 1 : 0, a.country == "US" ? 0 : 1, KIND_RANK.fetch(a.kind, 8), a.code.length, a.code ] }
    (exact.sort_by(&rank) + prefix.sort_by(&rank) + named.sort_by(&rank)).uniq(&:id).first(limit)
  end
end
