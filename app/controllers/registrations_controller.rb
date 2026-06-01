class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:email, :password, :password_confirmation, :timezone))
    if @user.save
      start_new_session_for(@user)
      redirect_to root_path, notice: "Welcome! You've signed up successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    if BCrypt::Password.new(current_user.password_digest).is_password?(params[:password])
      current_user.destroy
      terminate_session
      redirect_to root_path, notice: "Your account has been deleted."
    else
      redirect_to edit_settings_path, alert: "Incorrect password. Account not deleted."
    end
  end
end
