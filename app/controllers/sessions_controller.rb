class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create two_factor verify_two_factor]
  skip_before_action :require_two_factor_setup
  rate_limit to: 10, within: 3.minutes, only: %i[create verify_two_factor], with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
    redirect_to new_setup_path unless User.exists?
  end

  def create
    return redirect_to(new_session_path, alert: "Sign in with #{Sso.label}.") unless Sso.password_login?
    user = User.authenticate_with_lockout(email_address: params[:email_address], password: params[:password])
    if user&.disabled?
      redirect_to new_session_path, alert: "This account is disabled."
    elsif user
      begin_sign_in user, return_to: after_authentication_url
    else
      redirect_to new_session_path, alert: "Wrong email or password. After #{User::LOCK_AFTER} tries the account locks for #{User::LOCK_FOR.in_minutes.to_i} minutes."
    end
  end

  def two_factor
    redirect_to new_session_path, alert: "Sign in again." unless pending_otp_user
  end
  helper_method :pending_otp_user

  def verify_two_factor
    user = pending_otp_user
    return redirect_to(new_session_path, alert: "That took too long. Sign in again.") unless user
    if user.locked?
      reset_session
      redirect_to new_session_path, alert: "Too many tries. Try again later."
    elsif user.verify_second_factor(params[:code])
      user.clear_failed_sign_ins!
      return_to = after_authentication_url
      reset_session
      start_new_session_for user
      notice = user.recovery_codes_left < 3 ? "Only #{user.recovery_codes_left} recovery codes left. Make new ones on your profile." : nil
      redirect_to return_to, notice: notice
    else
      user.register_failed_sign_in!
      redirect_to two_factor_session_path, alert: "That code didn't work."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
