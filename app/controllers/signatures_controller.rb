# Supervisor sign-off queue: review entries sent to you, then sign them (one
# or many at once) after confirming who you are (password and authenticator
# code, or a fresh sign-in at the SSO provider), or return them to the
# technician with a note.
class SignaturesController < ApplicationController
  before_action :require_electronic_signatures, :require_supervisor
  rate_limit to: 10, within: 5.minutes, only: :create, with: -> { redirect_to signatures_path, alert: "Try again later." }

  def index
    @entries = current_user.entries_to_sign.awaiting_signature.includes(:user, :aircraft).order(:user_id, :performed_on)
    @certificates = current_user.signing_certificates
    @sso_confirmed = sso_confirmed?
    session[:after_reauth] = signatures_path if Sso.enabled? && current_user.sso_linked?
    @recent = EntrySignature.where(user: current_user).includes(work_entry: :user).order(signed_at: :desc).limit(15)
  end

  def create
    entries = current_user.entries_to_sign.awaiting_signature.where(id: Array(params[:entry_ids])).to_a
    certificate = current_user.signing_certificates.find { _1.id.to_s == params[:certificate_id].to_s }
    return redirect_to(signatures_path, alert: "Choose at least one entry.") if entries.empty?
    return redirect_to(signatures_path, alert: "Add a current certificate to your profile first.") unless certificate
    auth_method = sso_confirmed? ? "sso" : "password_totp"
    if auth_method == "password_totp" && !(current_user.authenticate(params[:password].to_s) && current_user.verify_second_factor(params[:code]))
      current_user.register_failed_sign_in!
      return redirect_to(signatures_path, alert: "Your password or authenticator code didn't match. Nothing was signed.")
    end

    signed, skipped = [], []
    entries.each do |entry|
      EntrySignature.sign!(entry, by: current_user, certificate:, ip_address: request.remote_ip, auth_method:)
      signed << entry
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      skipped << "#{entry.performed_on} #{entry.user.name}: #{e.message}"
    end
    flash[:notice] = "Signed #{signed.size} #{"entry".pluralize(signed.size)}." if signed.any?
    flash[:alert] = "Not signed: #{skipped.join("; ")}" if skipped.any?
    session.delete(:sso_signed_in_at) if auth_method == "sso" # one confirmation per batch
    redirect_to signatures_path
  end

  def return_entry
    entry = current_user.entries_to_sign.awaiting_signature.find(params[:id])
    entry.return!(params[:reason])
    redirect_to signatures_path, notice: "Returned to #{entry.user.name}."
  end

  private

  # Signed in at the SSO provider within the last few minutes, as this user.
  def sso_confirmed?
    Sso.enabled? && current_user.sso_linked? &&
      session[:sso_signed_in_at].to_i > Sso::REAUTH_FOR.ago.to_i
  end
end
