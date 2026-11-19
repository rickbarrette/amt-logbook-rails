# An aircraft worked on. Details come from the FAA registry when the N-number
# is found in the imported database, or are typed in.
class Aircraft < ApplicationRecord
  has_many :work_entries, dependent: :restrict_with_error
  has_many :timers, dependent: :nullify

  normalizes :n_number, with: ->(n) { Aircraft.normalize_n_number(n) }
  validates :n_number, presence: true, uniqueness: true, format: { with: /\AN[0-9A-Z]{1,5}\z/, message: "isn't a valid N-number" }

  # "n 123ab" -> "N123AB"
  def self.normalize_n_number(value)
    v = value.to_s.upcase.gsub(/[^0-9A-Z]/, "")
    v.present? && !v.start_with?("N") ? "N#{v}" : v
  end

  # Typed without details, or filled from the registry before: safe to
  # (re)fill from the registry. Details typed by hand are left alone.
  scope :registry_refreshable, -> { where(source: "registry").or(where(manufacturer: [ nil, "" ], model: [ nil, "" ])) }

  # Finds or creates the aircraft, filling details from the registry (also for
  # one added before the registry was imported).
  def self.lookup!(n_number)
    n = normalize_n_number(n_number)
    if (aircraft = find_by(n_number: n))
      aircraft.refresh_from_registry! if aircraft.manufacturer.blank? && aircraft.model.blank?
      return aircraft
    end
    record = RegistryRecord.find_by_n_number(n)
    create!(record ? record.aircraft_attributes : { n_number: n })
  end

  # Returns how many aircraft were updated.
  def self.refresh_from_registry!
    registry_refreshable.find_each.count(&:refresh_from_registry!)
  end

  def description = [ year_manufactured, manufacturer, model ].compact_blank.join(" ")
  def to_s = description.present? ? "#{n_number} (#{description})" : n_number

  def refresh_from_registry!
    record = RegistryRecord.find_by_n_number(n_number) or return false
    update!(record.aircraft_attributes)
    true
  end
end
