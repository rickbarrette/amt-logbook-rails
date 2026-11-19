class Admin::SettingsController < Admin::BaseController
  def show
  end

  def update
    mode = params[:signature_mode].to_s
    return redirect_to(admin_settings_path, alert: "Choose a signature mode.") unless Setting::SIGNATURE_MODES.key?(mode)
    Setting.set("signature_mode", mode)
    redirect_to admin_settings_path, notice: "Settings saved."
  end
end
