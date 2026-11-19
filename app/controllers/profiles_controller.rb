class ProfilesController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    attrs = params.expect(user: %i[name time_zone rating_goal experience_started_on])
    if @user.update(attrs)
      redirect_to profile_path, notice: "Profile saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def password
    @user = current_user
    if !@user.authenticate(params[:current_password].to_s)
      redirect_to profile_path, alert: "Your current password didn't match."
    elsif @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      @user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to profile_path, notice: "Password changed. Other devices were signed out."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
