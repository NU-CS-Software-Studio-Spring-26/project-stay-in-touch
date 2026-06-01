class SettingsController < ApplicationController
  def edit; end

  def update
    if current_user.update(settings_params)
      redirect_to edit_settings_path, notice: "Settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def change_password
    if BCrypt::Password.new(current_user.password_digest).is_password?(params[:current_password])
      if current_user.update(password: params[:new_password], password_confirmation: params[:new_password_confirmation])
        redirect_to edit_settings_path, notice: "Password updated successfully."
      else
        redirect_to edit_settings_path, alert: current_user.errors.full_messages.to_sentence
      end
    else
      redirect_to edit_settings_path, alert: "Current password is incorrect."
    end
  end

  private

  def settings_params
    params.require(:user).permit(:timezone, :display_name, :meeting_interests, :matchmaking_enabled, :avatar)
  end
end
