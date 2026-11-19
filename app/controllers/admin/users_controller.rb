class Admin::UsersController < Admin::BaseController
  before_action :set_user, except: :index

  def index
    @users = User.ordered.includes(:supervisors, :certificates)
    @invitations = Invitation.pending.order(:created_at)
  end

  def edit
    @supervisors = User.active.where(supervisor: true).where.not(id: @user.id).ordered
  end

  def update
    attrs = params.expect(user: %i[name email_address admin technician supervisor rating_goal])
    if @user == current_user && attrs[:admin] == "0"
      return redirect_to edit_admin_user_path(@user), alert: "You can't remove your own admin access."
    end
    if @user.update(attrs)
      redirect_to admin_users_path, notice: "#{@user.name} updated."
    else
      @supervisors = User.active.where(supervisor: true).where.not(id: @user.id).ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def disable
    return redirect_to(admin_users_path, alert: "You can't disable yourself.") if @user == current_user
    @user.update!(disabled_at: Time.current)
    @user.sessions.destroy_all
    redirect_to admin_users_path, notice: "#{@user.name} disabled."
  end

  def enable
    @user.update!(disabled_at: nil, failed_sign_ins: 0, locked_until: nil)
    redirect_to admin_users_path, notice: "#{@user.name} enabled."
  end

  # Lost phone: they set up their authenticator again at next sign-in.
  def reset_two_factor
    @user.disable_otp!
    @user.sessions.destroy_all
    redirect_to edit_admin_user_path(@user), notice: "Two-factor reset for #{@user.name}."
  end

  private

  def set_user = @user = User.find(params[:id])
end
