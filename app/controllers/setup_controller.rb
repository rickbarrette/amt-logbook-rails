# First run: creates the first administrator when there are no accounts.
class SetupController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_two_factor_setup
  before_action { redirect_to new_session_path if User.exists? }

  def new
    @user = User.new
  end

  rate_limit to: 10, within: 5.minutes, only: :create, with: -> { redirect_to new_setup_path, alert: "Try again later." }

  def create
    @user = User.new(params.expect(user: %i[name email_address password password_confirmation]).merge(admin: true, technician: false, supervisor: false))
    unless SetupCode.valid?(params[:setup_code])
      @user.errors.add(:base, "That setup code isn't right. It's printed in the server log when the app starts.")
      return render(:new, status: :unprocessable_entity)
    end
    if @user.save
      SetupCode.clear!
      start_new_session_for @user
      redirect_to new_two_factor_path, notice: "Welcome! Set up two-factor sign-in for your admin account."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
