# A passkey (WebAuthn credential) someone registered to sign in with: the
# public key and use counter; the private key never leaves their device.
# Passkeys are created with user verification required (Face ID, a PIN…),
# so signing in with one counts as two factors.
class Passkey < ApplicationRecord
  belongs_to :user

  normalizes :name, with: ->(n) { n.to_s.strip.first(60) }
  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :name, presence: true

  scope :ordered, -> { order(:created_at) }

  def used!(sign_count)
    update_columns(sign_count:, last_used_at: Time.current)
  end
end
