# Suggests an entry's ATA chapter, category and ACS subject areas from its
# description: keyword rules (config/faa/suggestions.yml), plus the
# technician's own past entries with similar descriptions.
class EntrySuggester
  Suggestion = Data.define(:ata_chapter, :category, :subject_areas, :confidence)
  HISTORY_LIMIT = 400
  STOPWORDS = %w[a an and the of on in at to for with per from by as is was were removed installed replaced
                 reinstalled helped new old left right lh rh side inspected checked].to_set

  def self.rules = @rules ||= YAML.load_file(Rails.root.join("config/faa/suggestions.yml"))
  def self.chapters = rules.fetch("chapters")

  # [[regex, chapter, weight, areas], ...]
  def self.keywords
    @keywords ||= rules.fetch("keywords").map do |word, (chapter, weight, areas)|
      phrase = Regexp.escape(word.to_s.delete_suffix("*")).gsub("\\ ", "[\\s-]+")
      tail = word.to_s.end_with?("*") ? "\\w*" : ""
      [ /(?<![\w-])#{phrase}#{tail}(?![\w-])/i, chapter.to_s, weight.to_i, Array(areas) ]
    end
  end

  def initialize(user: nil)
    @user = user
  end

  # nil when nothing in the text points anywhere.
  def suggest(text)
    text = text.to_s
    return if text.strip.length < 4
    scores = Hash.new(0.0)
    areas = Hash.new(0.0)
    self.class.keywords.each do |regex, chapter, weight, extra|
      hits = [ text.scan(regex).size, 3 ].min # mentioned again: more likely what the entry is about
      next if hits.zero?
      weight *= 1 + (hits - 1) * 0.5
      scores[chapter] += weight
      extra.each { areas[_1] += weight }
    end
    history_votes(text).each { |chapter, vote| scores[chapter] += vote }
    return if scores.empty?

    chapter, score = scores.max_by { |c, s| [ s, -c.to_i ] }
    defaults = self.class.chapters.fetch(chapter, {})
    Array(defaults["areas"]).each { areas[_1] += score }
    category = majority_category(scores) || defaults["category"] || "general"
    # Areas from the category's own ACS section, plus General.
    sections = [ "general", category ].uniq
    picked = areas.sort_by { -_2 }.map(&:first).select { sections.include?(Faa.subject_area_section(_1)) }.first(3)
    Suggestion.new(ata_chapter: chapter, category:, subject_areas: picked,
                   confidence: score >= 6 ? "high" : (score >= 3 ? "medium" : "low"))
  end

  private

  def tokens(text) = text.downcase.scan(/[a-z][a-z0-9-]{2,}/).reject { STOPWORDS.include?(_1) }.to_set

  # Past entries that read like this one vote for their chapter: each
  # chapter gets its best match (so many look-alike entries don't pile up),
  # and an entry must share at least two words and a fair part of its wording.
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
      next if overlap < 2 || similarity < 0.25
      votes[chapter] = [ votes[chapter], 8.0 * similarity ].max
    end
    votes
  end

  # Category: where most of the evidence points (an oil change mentioned in
  # an airframe-heavy entry stays airframe).
  def majority_category(scores)
    by_cat = Hash.new(0.0)
    scores.each { |c, s| by_cat[self.class.chapters.dig(c, "category") || "general"] += s }
    by_cat.max_by { _2 }&.first
  end
end
