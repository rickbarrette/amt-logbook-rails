class CertificatesController < ApplicationController
  def create
    cert = current_user.certificates.new(params.expect(user_certificate: %i[kind number expires_on]))
    if cert.save
      redirect_to profile_path(anchor: "certificates"), notice: "Certificate added."
    else
      redirect_to profile_path(anchor: "certificates"), alert: cert.errors.full_messages.to_sentence
    end
  end

  def destroy
    current_user.certificates.find(params[:id]).destroy!
    redirect_to profile_path(anchor: "certificates"), notice: "Certificate removed.", status: :see_other
  end
end
