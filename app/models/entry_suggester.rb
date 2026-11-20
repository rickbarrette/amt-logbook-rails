# Suggests an entry's ATA chapter, category and ACS subject areas from its
# description: keyword rules (config/faa/suggestions.yml), plus the
# technician's own past entries with similar descriptions.
class EntrySuggester
  # also: a second, unrelated chapter the entry clearly covers too (a hint to
  # log it as its own entry), or nil.
  Suggestion = Data.define(:ata_chapter, :category, :subject_areas, :confidence, :also)
  HISTORY_LIMIT = 400
  HISTORY_WEIGHT = 6.0
  # Chapters that describe how or why work was done rather than what was
  # worked on; they never trigger the "log it separately" hint.
  GENERIC_CHAPTERS = %w[05 12 20].freeze
  # Words that say nothing about which system was worked on (they'd make
  # every "Assisted with…" entry look alike).
  STOPWORDS = %w[a an and the of on in at to for with per from by as is was were are be been this that it its
                 removed remove installed install replaced replace reinstalled reinstall helped help assist assisted
                 assisting performed perform completed complete accomplished new old left right lh rh side
                 inspected inspect checked check found work worked job task iaw mm ipc manual aircraft
                 troubleshoot troubleshot troubleshooting trouble shooting shot ops operational tested test
                 under supervision supervised all per out off up].to_set

  def self.rules = @rules ||= YAML.load_file(Rails.root.join("config/faa/suggestions.yml"))
  def self.chapters = rules.fetch("chapters")

  # [[regex, chapter, weight, areas], ...], longest phrases first: a phrase
  # uses up its words so the shorter keywords inside it don't count again.
  def self.keywords
    @keywords ||= rules.fetch("keywords").map do |word, (chapter, weight, areas)|
      word = word.to_s
      phrase = Regexp.escape(word.delete_suffix("*")).gsub("\\ ", "[\\s-]+")
      tail = word.end_with?("*") ? "\\w*" : ""
      [ /(?<![\w-])#{phrase}#{tail}(?![\w-])/i, chapter.to_s, weight.to_f, Array(areas), word.delete_suffix("*").length ]
    end.sort_by { -_5 }.map { _1.first(4) }
  end

  def initialize(user: nil)
    @user = user
  end

  # nil when nothing in the text points anywhere.
  def suggest(text)
    text = text.to_s
    return if text.strip.length < 4
    scores, areas = keyword_scores(text)
    keyword_only = scores.dup
    history_votes(text).each { |chapter, vote| scores[chapter] += vote }
    return if scores.empty?

    chapter, score = best(scores)
    defaults = self.class.chapters.fetch(chapter, {})
    # The chapter's usual areas count, but less than areas a keyword named.
    Array(defaults["areas"]).each { areas[_1] += score * 0.5 }
    category = majority_category(scores, chapter) || defaults["category"] || "general"
    # Areas from the category's own ACS section, plus General.
    sections = [ "general", category ].uniq
    picked = areas.sort_by { -_2 }.map(&:first).select { sections.include?(Faa.subject_area_section(_1)) }.first(3)
    Suggestion.new(ata_chapter: chapter, category:, subject_areas: picked,
                   confidence: score >= 6 ? "high" : (score >= 3 ? "medium" : "low"),
                   also: second_job(keyword_only, chapter))
  end

  private

  def keyword_scores(text)
    scores = Hash.new(0.0)
    areas = Hash.new(0.0)
    work = text.dup
    self.class.keywords.each do |regex, chapter, weight, extra|
      hits = 0
      work = work.gsub(regex) { |m| hits += 1; " " * m.length }
      next if hits.zero?
      weight *= 1 + ([ hits, 3 ].min - 1) * 0.5 # mentioned again: more likely what the entry is about
      scores[chapter] += weight
      extra.each { areas[_1] += weight }
    end
    [ scores, areas ]
  end

  # Highest score; on a tie, the more specific (non-generic) chapter.
  def best(scores)
    scores.max_by { |c, s| [ s, GENERIC_CHAPTERS.include?(c) ? 0 : 1, -c.to_i ] }
  end

  # A runner-up chapter from a different system with real keyword evidence:
  # "bled brakes, troubleshot charging system" is two jobs.
  def second_job(scores, top)
    return if GENERIC_CHAPTERS.include?(top)
    top_score = scores[top].to_f
    runner, score = scores.reject { |c, _| c == top || GENERIC_CHAPTERS.include?(c) || family(c) == family(top) }
                          .max_by { |c, s| [ s, -c.to_i ] }
    runner if runner && score >= 3 && score >= top_score * 0.5
  end

  # Chapters that are parts of one job when they appear together.
  def family(chapter)
    case chapter.to_i
    when 51..57 then :structure
    when 62..67 then :rotor
    when 71..85 then :engine
    when 27 then :structure # flight-control surfaces and their attach structure
    else chapter
    end
  end

  def tokens(text) = text.downcase.scan(/[a-z][a-z0-9-]{2,}/).reject { STOPWORDS.include?(_1) }.to_set

  # Past entries that read like this one vote for their chapter: each
  # chapter gets its best match (so many look-alike entries don't pile up),
  # and an entry must share at least two meaningful words and a fair part of
  # its wording.
  def history_votes(text)
    return {} unless @user
    mine = tokens(text)
    return {} if mine.size < 2
    votes = Hash.new(0.0)
    @user.work_entries.where.not(ata_chapter: [ nil, "" ]).order(id: :desc).limit(HISTORY_LIMIT)
         .pluck(:description, :ata_chapter).each do |desc, chapter|
      theirs = tokens(desc)
      overlap = (mine & theirs).size
      similarity = overlap.to_f / (mine | theirs).size
      next if overlap < 2 || similarity < 0.3
      votes[chapter] = [ votes[chapter], HISTORY_WEIGHT * similarity ].max
    end
    votes
  end

  # Category: where most of the evidence points (an oil change mentioned in
  # an airframe-heavy entry stays airframe). General shop practices don't
  # pull an entry away from the system it's about, and an inspection stays
  # General when what it found ("checked for corrosion") is only mentioned.
  def majority_category(scores, top)
    by_cat = Hash.new(0.0)
    scores.each { |c, s| by_cat[self.class.chapters.dig(c, "category") || "general"] += s }
    specific = by_cat.except("general")
    return "general" if specific.empty?
    top_cat, top_score = specific.max_by { _2 }
    general_lead = self.class.chapters.dig(top, "category") == "general" ? 1.0 : 1.5
    by_cat["general"] >= top_score * general_lead ? "general" : top_cat
  end
end
