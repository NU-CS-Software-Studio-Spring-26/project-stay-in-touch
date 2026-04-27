class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to login_path, alert: "Try again later." }

  def new; end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to login_path, alert: "Invalid email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to login_path, notice: "You have been signed out."
  end
end
