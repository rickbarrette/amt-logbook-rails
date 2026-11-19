# One aircraft from the FAA Releasable Aircraft database (MASTER.txt joined
# with ACFTREF.txt and ENGINE.txt). See RegistryImporter.
class RegistryRecord < ApplicationRecord
  AIRCRAFT_TYPES = {
    "1" => "Glider", "2" => "Balloon", "3" => "Blimp/Dirigible", "4" => "Fixed wing single engine",
    "5" => "Fixed wing multi engine", "6" => "Rotorcraft", "7" => "Weight-shift-control", "8" => "Powered parachute",
    "9" => "Gyroplane", "H" => "Hybrid lift", "O" => "Other"
  }.freeze
  ENGINE_TYPES = {
    "0" => "None", "1" => "Reciprocating", "2" => "Turbo-prop", "3" => "Turbo-shaft", "4" => "Turbo-jet",
    "5" => "Turbo-fan", "6" => "Ramjet", "7" => "2 Cycle", "8" => "4 Cycle", "9" => "Unknown", "10" => "Electric", "11" => "Rotary"
  }.freeze

  # The registry stores N-numbers without the leading N.
  def self.find_by_n_number(n) = find_by(n_number: Aircraft.normalize_n_number(n).delete_prefix("N"))

  def self.last_import = RegistryImport.where(status: "done").order(:finished_at).last

  def aircraft_attributes
    { n_number: "N#{n_number}", serial_number:, manufacturer:, model:, year_manufactured:, aircraft_type:,
      engine_type:, engine_manufacturer:, engine_model:, engines_count:, source: "registry" }
  end
end
