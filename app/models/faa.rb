# FAA reference data and experience rules, loaded from config/faa/*.yml.
module Faa
  module_function

  def rules = @rules ||= load("experience_rules")
  def hours_per_month = rules.fetch("hours_per_month").to_f
  def ratings = rules.fetch("ratings")
  def categories = rules.fetch("categories")
  def certificate_kinds = rules.fetch("certificate_kinds")
  def ata_chapters = @ata ||= load("ata_chapters")

  def acs_sections = @acs ||= load("acs_subject_areas")

  # { "G-A" => "Fundamentals of Electricity and Electronics", ... }
  def subject_areas = @areas ||= acs_sections.values.flat_map { _1["areas"].to_a }.to_h

  def subject_area_section(code) = acs_sections.find { |_, s| s["areas"].key?(code) }&.first

  def subject_area_label(code) = subject_areas[code] || code

  def ata_label(chapter) = chapter.present? ? "#{chapter} #{ata_chapters[chapter]}".strip : nil

  def certificate_short(kind) = certificate_kinds.dig(kind, "short") || kind

  def certificate_label(kind) = certificate_kinds.dig(kind, "label") || kind

  def load(name) = YAML.load_file(Rails.root.join("config/faa/#{name}.yml"))
end
