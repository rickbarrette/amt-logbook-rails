# An admin's invitation for someone to create an account.
class Invitation < ApplicationRecord
  VALID_FOR = 14.days

  belongs_to :invited_by, class_name: "User", optional: true
  belongs_to :user, optional: true
  has_secure_token :token, length: 32

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :name, presence: true
  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate { errors.add(:email_address, "already has an account") if new_record? && User.exists?(email_address: email_address) }
  before_validation { self.expires_at ||= VALID_FOR.from_now }

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }

  def self.find_usable(token) = pending.find_by(token: token.to_s)

  def accepted? = accepted_at.present?
  def expired? = expires_at.past?

  # Creates the account; returns the user (unsaved with errors on failure).
  def accept!(password:, password_confirmation:)
    user = User.new(name: name, email_address: email_address, admin: admin, technician: technician, supervisor: supervisor,
                    password: password, password_confirmation: password_confirmation)
    transaction do
      user.save!
      update!(accepted_at: Time.current, user: user)
    end
    user
  rescue ActiveRecord::RecordInvalid
    user
  end
end
