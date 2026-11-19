# A supervisor's FAA certificate (A&P, IA, repairman…), shown on each signature.
class UserCertificate < ApplicationRecord
  belongs_to :user

  normalizes :number, with: ->(n) { n.strip.upcase }
  validates :kind, inclusion: { in: ->(_) { Faa.certificate_kinds.keys } }
  validates :number, presence: true, length: { maximum: 40 }

  def expired?(today = Date.current) = expires_on.present? && today > expires_on
  def label = Faa.certificate_label(kind)
  def short_label = Faa.certificate_short(kind)
  def to_s = "#{short_label} #{number}"

  # Work categories this certificate may supervise (14 CFR 65.81).
  def covers?(category) = Array(Faa.certificate_kinds.dig(kind, "categories")).include?(category)
end
