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

  # Finds or creates the aircraft, filling details from the registry.
  def self.lookup!(n_number)
    n = normalize_n_number(n_number)
    find_by(n_number: n) || begin
      record = RegistryRecord.find_by_n_number(n)
      create!(record ? record.aircraft_attributes : { n_number: n })
    end
  end

  def description = [ year_manufactured, manufacturer, model ].compact_blank.join(" ")
  def to_s = description.present? ? "#{n_number} (#{description})" : n_number

  def refresh_from_registry!
    record = RegistryRecord.find_by_n_number(n_number) or return false
    update!(record.aircraft_attributes)
  end
end
