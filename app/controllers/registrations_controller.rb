class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:email, :password, :password_confirmation))
    if @user.save
      start_new_session_for(@user)
      redirect_to root_path, notice: "Welcome! You've signed up successfully."
    else
      render :new, status: :unprocessable_content
    end
  end
end
