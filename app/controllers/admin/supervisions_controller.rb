class Admin::SupervisionsController < Admin::BaseController
  def create
    technician = User.find(params[:user_id])
    sup = technician.supervisions_as_technician.new(supervisor_id: params[:supervisor_id])
    if sup.save
      redirect_to edit_admin_user_path(technician), notice: "#{sup.supervisor.name} can now sign #{technician.name}'s entries."
    else
      redirect_to edit_admin_user_path(technician), alert: sup.errors.full_messages.to_sentence
    end
  end

  def destroy
    sup = Supervision.find(params[:id])
    sup.destroy!
    redirect_to edit_admin_user_path(sup.technician), notice: "Removed.", status: :see_other
  end
end
