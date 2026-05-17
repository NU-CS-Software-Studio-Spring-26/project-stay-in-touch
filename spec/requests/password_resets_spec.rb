require "rails_helper"

RSpec.describe "Password Resets", type: :request do
  let(:user) { create(:user) }

  describe "GET /password_reset/new" do
    it "renders the forgot password form" do
      get new_password_reset_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Reset Password")
    end
  end

  describe "POST /password_reset" do
    context "with a valid email" do
      it "sends a reset email and shows success message" do
        expect {
          post password_reset_path, params: { email: user.email }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to redirect_to(new_password_reset_path)
        follow_redirect!
        expect(response.body).to include("If an account with that email exists")
      end

      it "includes the reset token in the email" do
        post password_reset_path, params: { email: user.email }
        email = ActionMailer::Base.deliveries.last
        expect(email.to).to include(user.email)
        expect(email.subject).to include("Reset your password")
      end
    end

    context "with a non-existent email" do
      it "shows the same success message (no email enumeration)" do
        expect {
          post password_reset_path, params: { email: "nobody@example.com" }
        }.not_to change { ActionMailer::Base.deliveries.count }

        expect(response).to redirect_to(new_password_reset_path)
        follow_redirect!
        expect(response.body).to include("If an account with that email exists")
      end
    end
  end

  describe "GET /password_reset/edit" do
    context "with a valid token" do
      it "renders the reset password form" do
        raw_token = user.generate_reset_token
        get edit_password_reset_path(token: raw_token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Set New Password")
      end
    end

    context "with an invalid token" do
      it "redirects to forgot password with error" do
        get edit_password_reset_path(token: "invalid-token")
        expect(response).to redirect_to(new_password_reset_path)
        follow_redirect!
        expect(response.body).to include("Invalid or expired")
      end
    end

    context "with an expired token" do
      it "redirects to forgot password with error" do
        raw_token = user.generate_reset_token
        user.update!(reset_token_expires_at: 2.hours.ago)
        get edit_password_reset_path(token: raw_token)
        expect(response).to redirect_to(new_password_reset_path)
      end
    end
  end

  describe "PATCH /password_reset" do
    context "with valid token and matching passwords" do
      it "resets the password and clears the token" do
        raw_token = user.generate_reset_token
        old_digest = user.password_digest

        patch password_reset_path(token: raw_token), params: {
          password: "NewSecure1!Pass",
          password_confirmation: "NewSecure1!Pass"
        }

        expect(response).to redirect_to(login_path)
        expect(user.reload.reset_token).to be_nil
        expect(user.reload.password_digest).not_to eq(old_digest)
      end
    end

    context "with mismatched passwords" do
      it "redirects back with error" do
        raw_token = user.generate_reset_token

        patch password_reset_path(token: raw_token), params: {
          password: "NewSecure1!Pass",
          password_confirmation: "Different1!Pass"
        }

        expect(response).to redirect_to(edit_password_reset_path(token: raw_token))
        follow_redirect!
        expect(response.body).to include("Password confirmation doesn&#39;t match")
        expect(user.reload.reset_token).to be_present
      end
    end

    context "with password that fails complexity" do
      it "redirects back with error" do
        raw_token = user.generate_reset_token

        patch password_reset_path(token: raw_token), params: {
          password: "weak",
          password_confirmation: "weak"
        }

        expect(response).to redirect_to(edit_password_reset_path(token: raw_token))
        follow_redirect!
        expect(response.body).to include("password")
        expect(user.reload.reset_token).to be_present
      end
    end

    context "with invalid token" do
      it "redirects to forgot password with error" do
        patch password_reset_path(token: "invalid"), params: {
          password: "NewSecure1!Pass",
          password_confirmation: "NewSecure1!Pass"
        }

        expect(response).to redirect_to(new_password_reset_path)
      end
    end
  end
end
