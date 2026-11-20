# One logbook entry: practical experience performed on a day.
#
# Electronic signatures: draft -> submitted -> signed (permanent), or
# returned for changes. Ink only (Admin → Settings): draft -> recorded, with
# the supervisor's name and certificate typed on the entry, to be signed by
# hand on the printed logbook.
class WorkEntry < ApplicationRecord
  STATUSES = %w[draft submitted returned signed recorded].freeze
  MAX_MINUTES = 24 * 60

  belongs_to :user
  belongs_to :aircraft, optional: true
  belongs_to :supervisor, class_name: "User", optional: true
  belongs_to :entry_import, optional: true
  has_one :signature, class_name: "EntrySignature", dependent: :destroy
  has_one :timer, dependent: :nullify

  attribute :subject_areas, :json, default: -> { [] }
  attr_accessor :n_number

  normalizes :description, with: ->(d) { d.strip }
  normalizes :supervisor_name, :supervisor_certificate, with: ->(v) { v.strip.presence }
  validates :performed_on, :description, presence: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_MINUTES }
  validates :category, inclusion: { in: ->(_) { Faa.categories.keys } }
  validates :status, inclusion: { in: STATUSES }
  validates :supervisor_name, :supervisor_certificate, length: { maximum: 100 }
  validates :ata_chapter, inclusion: { in: ->(_) { Faa.ata_chapters.keys } }, allow_blank: true
  validate :subject_areas_known
  validate :not_in_future
  validate :supervisor_allowed, if: -> { supervisor_id.present? && will_save_change_to_supervisor_id? }
  before_validation :normalize_subject_areas

  # Signed entries are part of the permanent record.
  before_update { throw :abort if status_was == "signed" && !destroyed_by_association }
  before_destroy { throw :abort if signed? && !destroyed_by_association }

  scope :chronological, -> { order(:performed_on, :id) }
  scope :recent, -> { order(performed_on: :desc, id: :desc) }
  scope :signed, -> { where(status: "signed") }
  scope :awaiting_signature, -> { where(status: "submitted") }
  # Entries that count toward the experience requirement: signed ones, or in
  # ink-only mode every finished entry (the signature is on paper).
  scope :counted, -> { Setting.ink_signatures? ? where(status: %w[signed recorded submitted]) : signed }
  scope :between, ->(from, to) { where(performed_on: (from || Date.new(1900))..(to || Date.new(3000))) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }
  def editable? = draft? || returned? || recorded?
  def counted? = Setting.ink_signatures? ? %w[signed recorded submitted].include?(status) : signed?

  # Who supervised: the e-signature, else as typed (ink mode), else the app supervisor.
  def supervisor_display_name = signature&.signer_name || supervisor_name.presence || supervisor&.name
  def supervisor_display_certificate
    return signature.certificate_label if signature
    supervisor_name.present? ? supervisor_certificate.presence : supervisor&.certificates&.first&.to_s
  end

  def record!
    raise ArgumentError, "clock out first" if clocking?
    update!(status: "recorded", submitted_at: Time.current, returned_reason: nil)
  end

  def hours = (minutes.to_i / 60.0).round(1)
  def hours=(value)
    self.minutes = (value.to_f * 60).round if value.present?
  end

  def imported? = import_details.present?
  # Its timer is still running or paused: hours aren't known yet.
  def clocking? = timer.present? && !timer.stopped?
  def category_label = Faa.categories[category]
  def ata_label = Faa.ata_label(ata_chapter)
  def subject_area_labels = subject_areas.map { Faa.subject_area_label(_1) }

  def submit!(to: supervisor)
    raise ArgumentError, "choose a supervisor" unless to
    raise ArgumentError, "clock out first" if clocking?
    update!(supervisor: to, status: "submitted", submitted_at: Time.current, returned_reason: nil)
  end

  def return!(reason)
    update!(status: "returned", returned_reason: reason.to_s.strip.presence || "Returned for changes")
  end

  # The content that a signature certifies; any later change is detectable.
  def content
    { "entry_id" => id, "technician" => user.name, "performed_on" => performed_on.iso8601, "minutes" => minutes,
      "category" => category, "aircraft" => aircraft&.n_number, "aircraft_description" => aircraft&.description,
      "ata_chapter" => ata_chapter, "subject_areas" => subject_areas, "description" => description,
      "reference" => reference, "location" => location }.merge(
        supervisor_name.present? ? { "supervisor_name" => supervisor_name, "supervisor_certificate" => supervisor_certificate } : {})
  end

  def content_digest = Digest::SHA256.hexdigest(content.to_json)

  private

  def normalize_subject_areas
    self.subject_areas = Array(subject_areas).compact_blank.map(&:to_s).uniq
  end

  def subject_areas_known
    unknown = subject_areas - Faa.subject_areas.keys
    errors.add(:subject_areas, "includes unknown areas: #{unknown.join(", ")}") if unknown.any?
  end

  def not_in_future
    errors.add(:performed_on, "can't be in the future") if performed_on && performed_on > Date.current + 1
  end

  def supervisor_allowed
    errors.add(:supervisor, "isn't one of your supervisors") unless user.supervisors.exists?(supervisor_id)
  end
end
