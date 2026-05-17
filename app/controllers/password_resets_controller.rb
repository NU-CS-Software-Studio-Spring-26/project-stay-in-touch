class PasswordResetsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_password_reset_path, alert: "Try again later." }

  def new
  end

  def create
    user = User.find_by(email: params[:email])
    if user
      raw_token = user.generate_reset_token
      PasswordResetMailer.reset_instructions(user, raw_token).deliver_now
    end
    redirect_to new_password_reset_path, notice: "If an account with that email exists, you will receive password reset instructions."
  end

  def edit
    @user = User.find_by(reset_token: Digest::SHA256.hexdigest(params[:token]))
    if @user.nil? || !@user.reset_token_valid?(params[:token])
      redirect_to new_password_reset_path, alert: "Invalid or expired reset link. Please request a new one."
    end
  end

  def update
    @user = User.find_by(reset_token: Digest::SHA256.hexdigest(params[:token]))
    if @user.nil? || !@user.reset_token_valid?(params[:token])
      redirect_to new_password_reset_path, alert: "Invalid or expired reset link. Please request a new one."
      return
    end

    if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      @user.clear_reset_token!
      redirect_to login_path, notice: "Your password has been reset. Please log in with your new password."
    else
      redirect_to edit_password_reset_path(token: params[:token]),
                  alert: @user.errors.full_messages.to_sentence
    end
  end
end
