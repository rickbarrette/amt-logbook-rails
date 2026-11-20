# Profile → Two-factor: set up an authenticator app, turn it off, or make new recovery codes.
class TwoFactorsController < ApplicationController
  skip_before_action :require_two_factor_setup
  rate_limit to: 10, within: 5.minutes, only: %i[create destroy recovery_codes], with: -> { redirect_to profile_path, alert: "Try again later." }

  def new
    return redirect_to(profile_path, notice: "Two-factor is already on.") if current_user.otp_enabled?
    session[:pending_otp_secret] ||= User.new_otp_secret
    @secret = session[:pending_otp_secret]
    svg = RQRCode::QRCode.new(User.otp_uri(@secret, current_user.email_address)).as_svg(module_size: 4, use_path: true, viewbox: true)
    @qr_data_uri = "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end

  def create
    secret = session[:pending_otp_secret]
    return redirect_to(new_two_factor_path) unless secret
    if User.valid_otp?(secret, params[:code])
      session.delete(:pending_otp_secret)
      @codes = current_user.enable_otp!(secret)
      render :codes
    else
      redirect_to new_two_factor_path, alert: "That code didn't work. Check the time on your phone and try again."
    end
  end

  def recovery_codes
    return redirect_to(profile_path, alert: "That code didn't work.") unless current_user.verify_second_factor(params[:code])
    @codes = current_user.enable_otp!(current_user.otp_secret)
    render :codes
  end

  def destroy
    return redirect_to(profile_path, alert: "You must keep two-factor on: add a passkey first, or keep the authenticator.") if current_user.otp_required? && current_user.passkeys.none?
    return redirect_to(profile_path, alert: "That code didn't work.") unless current_user.verify_second_factor(params[:code])
    current_user.disable_otp!
    redirect_to profile_path, notice: "Two-factor is off."
  end
end
