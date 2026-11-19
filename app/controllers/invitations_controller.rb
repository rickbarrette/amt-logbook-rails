# Accepting an admin's invitation: choose a password, and the account exists.
class InvitationsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_two_factor_setup
  before_action :set_invitation

  def show
  end

  def update
    @user = @invitation.accept!(password: params[:password], password_confirmation: params[:password_confirmation])
    if @user.persisted?
      reset_session
      start_new_session_for @user
      redirect_to(@user.otp_required? ? new_two_factor_path : root_path, notice: "Welcome, #{@user.name}!")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_invitation
    @invitation = Invitation.find_usable(params[:token])
    redirect_to new_session_path, alert: "That invitation has expired or was already used." unless @invitation
  end
end
