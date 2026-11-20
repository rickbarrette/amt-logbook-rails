# Forgotten password: an emailed link (or one an admin makes on the user's
# page when email isn't set up) to choose a new one. A reset also lifts a
# sign-in lockout and signs out every device.
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_two_factor_setup
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: %i[create update], with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    return redirect_to(new_session_path, alert: "Email isn't set up here. Ask your administrator for a password reset link.") unless User.mail_configured?
    if (user = User.active.find_by(email_address: params[:email_address].to_s.strip.downcase))
      PasswordsMailer.reset(user).deliver_later
    end
    redirect_to new_session_path, notice: "If that email has an account, a reset link is on its way. It works for an hour."
  end

  def edit
  end

  def update
    if params[:password].blank?
      redirect_to edit_password_path(params[:token]), alert: "Choose a new password."
    elsif @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      @user.clear_failed_sign_ins!
      redirect_to new_session_path, notice: "Password changed. Sign in with the new one."
    else
      redirect_to edit_password_path(params[:token]), alert: @user.errors.full_messages.to_sentence
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_password_path, alert: "That reset link is invalid or has expired."
    end
end
