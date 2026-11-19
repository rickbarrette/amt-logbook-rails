# A supervisor's electronic signature on a work entry.
#
# Records who signed, with which certificate, the statement certified, when,
# and how they proved who they were (password + authenticator code).
# content_digest is a SHA-256 of the entry at signing (content_snapshot holds
# that content) so any later change shows; seal is an HMAC over the signature
# keyed by this server, so the record can't be edited unnoticed either.
class EntrySignature < ApplicationRecord
  AUTH_METHODS = %w[password_totp].freeze

  belongs_to :work_entry
  belongs_to :user, optional: true

  validates :signer_name, :certificate_kind, :certificate_number, :statement, :signed_at, :content_digest, :content_snapshot, presence: true
  validates :auth_method, inclusion: { in: AUTH_METHODS }
  validates :work_entry_id, uniqueness: true
  before_validation(on: :create) { self.seal ||= compute_seal }
  before_update { throw :abort } # signatures are permanent
  before_destroy { throw :abort unless destroyed_by_association }

  def self.statement_for(entry, supervisor)
    "I certify that #{entry.user.name} performed the work described in this entry under my supervision " \
      "on #{entry.performed_on.strftime("%b %-d, %Y")}, for #{entry.hours} hours, and that this record is true and correct."
  end

  # Signs the entry. Caller has already checked password and second factor.
  def self.sign!(entry, by:, certificate:, ip_address: nil)
    raise ArgumentError, "entry isn't awaiting your signature" unless entry.submitted? && entry.supervisor_id == by.id
    raise ArgumentError, "#{certificate} doesn't cover #{entry.category_label.downcase} work" unless certificate.covers?(entry.category)
    raise ArgumentError, "certificate expired" if certificate.expired?
    transaction do
      sig = entry.create_signature!(
        user: by, signer_name: by.name, certificate_kind: certificate.kind, certificate_number: certificate.number,
        statement: statement_for(entry, by), signed_at: Time.current, content_digest: entry.content_digest,
        content_snapshot: entry.content.to_json, auth_method: "password_totp", ip_address:
      )
      entry.update!(status: "signed")
      sig
    end
  end

  def self.seal_key = Rails.application.key_generator.generate_key("entry-signature-seal", 32)

  def compute_seal
    payload = [ work_entry_id, user_id, signer_name, certificate_kind, certificate_number, statement,
                signed_at&.utc&.iso8601(6), content_digest, auth_method ].join("\u001f")
    OpenSSL::HMAC.hexdigest("SHA256", self.class.seal_key, payload)
  end

  def certificate_label = "#{Faa.certificate_short(certificate_kind)} #{certificate_number}"
  def seal_valid? = seal.present? && ActiveSupport::SecurityUtils.secure_compare(seal, compute_seal)
  def content_matches? = content_digest == work_entry.content_digest
  def intact? = seal_valid? && content_matches?
end
