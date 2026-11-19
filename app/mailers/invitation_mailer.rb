class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    mail to: invitation.email_address, subject: "You're invited to AMT Logbook"
  end
end
