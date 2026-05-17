class PasswordResetMailer < ApplicationMailer
  def reset_instructions(user, token)
    @user = user
    @token = token
    @reset_url = edit_password_reset_url(token: @token)

    mail(to: @user.email, subject: "Reset your password")
  end
end
