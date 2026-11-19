# App-wide settings an admin changes on Admin → Settings.
class Setting < ApplicationRecord
  SIGNATURE_MODES = {
    "electronic" => "Electronic and ink: supervisors sign in the app; the printout also has ink-signature lines",
    "ink" => "Ink only: supervisors sign the printed logbook by hand; no supervisor accounts needed"
  }.freeze
  DEFAULTS = { "signature_mode" => "electronic" }.freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key) = find_by(key: key.to_s)&.value || DEFAULTS[key.to_s]

  def self.set(key, value)
    find_or_initialize_by(key: key.to_s).update!(value: value.to_s)
  end

  def self.signature_mode = SIGNATURE_MODES.key?(get("signature_mode")) ? get("signature_mode") : "electronic"
  def self.ink_signatures? = signature_mode == "ink"
  def self.electronic_signatures? = !ink_signatures?
end
