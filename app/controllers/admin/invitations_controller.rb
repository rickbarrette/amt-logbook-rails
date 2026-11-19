class Admin::InvitationsController < Admin::BaseController
  def new
    @invitation = Invitation.new(technician: true)
  end

  def create
    @invitation = Invitation.new(params.expect(invitation: %i[name email_address admin technician supervisor]).merge(invited_by: current_user))
    if @invitation.save
      InvitationMailer.invite(@invitation).deliver_later if mail_configured?
      redirect_to admin_invitation_path(@invitation)
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Shows the link to copy, in case email isn't set up.
  def show
    @invitation = Invitation.find(params[:id])
  end

  def destroy
    Invitation.find(params[:id]).destroy!
    redirect_to admin_users_path, notice: "Invitation cancelled.", status: :see_other
  end

  private

  def mail_configured? = ENV["SMTP_ADDRESS"].present? || !Rails.env.production?
  helper_method :mail_configured?
end
