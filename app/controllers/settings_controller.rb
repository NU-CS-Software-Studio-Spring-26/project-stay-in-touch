class SettingsController < ApplicationController
  def edit; end

  def update
    if current_user.update(settings_params)
      redirect_to edit_settings_path, notice: "Settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def settings_params
    params.require(:user).permit(:timezone, :display_name, :meeting_interests, :matchmaking_enabled)
  end
end
