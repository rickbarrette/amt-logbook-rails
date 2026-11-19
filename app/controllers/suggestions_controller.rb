# JSON suggestions for the entry form: ATA chapter/category/ACS areas from a
# description, and locations and N-numbers from history and reference data.
class SuggestionsController < ApplicationController
  LIMIT = 8

  # GET /suggestions/entry?text=…
  def entry
    s = EntrySuggester.new(user: current_user).suggest(params[:text].to_s.first(5000))
    return render(json: { found: false }) unless s
    render json: { found: true, ata_chapter: s.ata_chapter, ata_label: Faa.ata_label(s.ata_chapter),
                   category: s.category, category_label: Faa.categories[s.category], confidence: s.confidence,
                   subject_areas: s.subject_areas.map { { code: _1, label: Faa.subject_area_label(_1) } } }
  end

  # GET /suggestions/locations?q=… — places you've logged first, then airports.
  def locations
    q = params[:q].to_s.strip
    used = current_user.work_entries.where.not(location: [ nil, "" ]).group(:location)
                       .order(Arel.sql("COUNT(*) DESC, MAX(performed_on) DESC")).limit(50).count.keys
    used = used.select { _1.downcase.include?(q.downcase) } if q.present?
    history = used.first(LIMIT).map do |loc|
      airport = Airport.lookup(loc)
      { value: loc, label: airport&.name || "Used before", detail: airport ? [ airport.place, "used before" ].compact_blank.join(" · ") : nil, history: true }
    end
    airports = q.length >= 2 ? Airport.search(q, limit: LIMIT).map(&:as_suggestion) : []
    render json: (history + airports.reject { |a| used.include?(a[:value]) }).first(LIMIT + 2)
  end

  # GET /suggestions/aircraft?q=… — aircraft you've worked on first, then the registry.
  def aircraft
    q = Aircraft.normalize_n_number(params[:q]).delete_prefix("N")
    mine = Aircraft.joins(:work_entries).where(work_entries: { user_id: current_user.id })
                   .group("aircraft.id").order(Arel.sql("MAX(work_entries.performed_on) DESC")).limit(50).to_a
    mine = mine.select { _1.n_number.delete_prefix("N").start_with?(q) } if q.present?
    history = mine.first(LIMIT).map { { value: _1.n_number, label: _1.description.presence || "Worked on before", detail: "worked on before", history: true } }
    registry = if q.length >= 2
      RegistryRecord.where("n_number LIKE ?", "#{RegistryRecord.sanitize_sql_like(q)}%").order(:n_number).limit(LIMIT).map do |r|
        { value: "N#{r.n_number}", label: [ r.year_manufactured, r.manufacturer, r.model ].compact_blank.join(" "), detail: "FAA registry" }
      end
    else
      []
    end
    taken = history.map { _1[:value] }
    render json: (history + registry.reject { taken.include?(_1[:value]) }).first(LIMIT + 2)
  end
end
