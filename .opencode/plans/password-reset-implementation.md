# Password Reset Implementation - Issue #97

## Files to Create

### 1. `db/migrate/20260517135851_add_reset_token_to_users.rb`

```ruby
class AddResetTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :reset_token, :string
    add_column :users, :reset_token_expires_at, :datetime
    add_index :users, :reset_token
  end
end
```

### 2. `app/models/user.rb` - Add these methods

Add after line 20 (after `google_calendar_connected?`):

```ruby
  RESET_TOKEN_EXPIRATION = 1.hour

  def generate_reset_token
    raw_token = SecureRandom.urlsafe_base64
    self.reset_token = BCrypt::Password.create(raw_token)
    self.reset_token_expires_at = Time.current + RESET_TOKEN_EXPIRATION
    save!
    raw_token
  end

  def reset_token_valid?(raw_token)
    reset_token.present? &&
      reset_token_expires_at.present? &&
      reset_token_expires_at > Time.current &&
      BCrypt::Password.new(reset_token).is_password?(raw_token)
  end

  def clear_reset_token!
    update!(reset_token: nil, reset_token_expires_at: nil)
  end
```

### 3. `app/mailers/password_reset_mailer.rb`

```ruby
class PasswordResetMailer < ApplicationMailer
  def reset_instructions(user, token)
    @user = user
    @token = token
    @reset_url = edit_password_reset_url(token: @token)

    mail(to: @user.email, subject: "Reset your password")
  end
end
```

### 4. `app/views/password_reset_mailer/reset_instructions.html.erb`

```erb
<p>Hi,</p>

<p>Someone requested a password reset for your Stay In Touch account. If this was you, click the link below to set a new password:</p>

<p style="text-align: center; margin: 24px 0;">
  <%= link_to "Reset my password", @reset_url, class: "btn btn-accept", style: "background: #0d6efd; color: #fff; padding: 12px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; display: inline-block;" %>
</p>

<p>Or copy and paste this URL into your browser:</p>
<p style="word-break: break-all; font-size: 13px; color: #6c757d;"><%= @reset_url %></p>

<div class="footer">
  <p>This link expires in 1 hour and can only be used once.</p>
  <p>If you didn't request a password reset, you can safely ignore this email.</p>
</div>
```

### 5. `app/views/password_reset_mailer/reset_instructions.text.erb`

```erb
Hi,

Someone requested a password reset for your Stay In Touch account. If this was you, click the link below to set a new password:

<%= @reset_url %>

This link expires in 1 hour and can only be used once.

If you didn't request a password reset, you can safely ignore this email.
```

### 6. `app/controllers/password_resets_controller.rb`

```ruby
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
    @user = User.find_by(reset_token: params[:token])
    if @user.nil? || !@user.reset_token_valid?(params[:token])
      redirect_to new_password_reset_path, alert: "Invalid or expired reset link. Please request a new one."
    end
  end

  def update
    @user = User.find_by(reset_token: params[:token])
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
```

### 7. `app/views/password_resets/new.html.erb`

```erb
<% content_for :title, "Forgot Password" %>

<div class="row justify-content-center mt-5">
  <div class="col-md-5">
    <div class="card shadow-sm">
      <div class="card-body p-4">
        <h1 class="h3 mb-3 text-center">Reset Password</h1>
        <p class="text-muted text-center mb-4 small">Enter your email address and we'll send you instructions to reset your password.</p>

        <%= form_with url: password_reset_path, class: "vstack gap-3" do |f| %>
          <div>
            <%= f.label :email, class: "form-label" %>
            <%= f.email_field :email, required: true, autofocus: true,
                  autocomplete: "email", class: "form-control" %>
          </div>
          <%= f.submit "Send Reset Instructions", class: "btn btn-primary w-100" %>
        <% end %>

        <hr>
        <p class="text-center mb-0 small">
          <%= link_to "Back to Log In", login_path %>
        </p>
      </div>
    </div>
  </div>
</div>
```

### 8. `app/views/password_resets/edit.html.erb`

```erb
<% content_for :title, "Set New Password" %>

<div class="row justify-content-center mt-5">
  <div class="col-md-5">
    <div class="card shadow-sm">
      <div class="card-body p-4">
        <h1 class="h3 mb-4 text-center">Set New Password</h1>

        <%= form_with url: password_reset_path(token: params[:token]), method: :patch, class: "vstack gap-3" do |f| %>
          <div>
            <%= f.label :password, "New Password", class: "form-label" %>
            <%= f.password_field :password, required: true, autofocus: true,
                  autocomplete: "new-password", maxlength: 72, class: "form-control" %>
          </div>
          <div>
            <%= f.label :password_confirmation, "Confirm New Password", class: "form-label" %>
            <%= f.password_field :password_confirmation, required: true,
                  autocomplete: "new-password", maxlength: 72, class: "form-control" %>
          </div>
          <%= f.submit "Reset Password", class: "btn btn-primary w-100" %>
        <% end %>

        <hr>
        <p class="text-center mb-0 small">
          <%= link_to "Back to Log In", login_path %>
        </p>
      </div>
    </div>
  </div>
</div>
```

## Files to Modify

### 9. `config/routes.rb`

Add after the logout line (line 7):

```ruby
  resource :password_reset, only: %i[new create edit update]
```

### 10. `app/views/sessions/new.html.erb`

Add after line 40 (after the `<hr>` and before the "New here?" paragraph):

```erb
        <p class="text-center mb-2 small">
          <%= link_to "Forgot your password?", new_password_reset_path %>
        </p>
```

## Tests to Create

### 11. `spec/models/user_spec.rb` - Add to existing describe block

```ruby
  describe "password reset" do
    let(:user) { create(:user) }

    describe "#generate_reset_token" do
      it "sets reset_token and reset_token_expires_at" do
        expect(user.reset_token).to be_nil
        expect(user.reset_token_expires_at).to be_nil

        raw_token = user.generate_reset_token

        expect(user.reset_token).to be_present
        expect(user.reset_token_expires_at).to be_present
        expect(user.reset_token_expires_at).to be_within(5.seconds).of(1.hour.from_now)
        expect(user.reset_token).not_to eq(raw_token)
      end
    end

    describe "#reset_token_valid?" do
      it "returns true for a valid, unexpired token" do
        raw_token = user.generate_reset_token
        expect(user.reset_token_valid?(raw_token)).to be true
      end

      it "returns false for an incorrect token" do
        user.generate_reset_token
        expect(user.reset_token_valid?("wrong-token")).to be false
      end

      it "returns false when token is expired" do
        user.generate_reset_token
        user.update!(reset_token_expires_at: 2.hours.ago)
        expect(user.reset_token_valid?("any-token")).to be false
      end

      it "returns false when no token exists" do
        expect(user.reset_token_valid?("any-token")).to be false
      end
    end

    describe "#clear_reset_token!" do
      it "removes the reset token" do
        user.generate_reset_token
        user.clear_reset_token!
        expect(user.reset_token).to be_nil
        expect(user.reset_token_expires_at).to be_nil
      end
    end
  end
```

### 12. `spec/requests/password_resets_spec.rb`

```ruby
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
        expect(response.body).to include("Password confirmation doesn't match")
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
```

## Local Testing Steps

1. Run the migration:
   ```
   rails db:migrate
   ```

2. Run the test suite:
   ```
   bundle exec rspec
   ```

3. Manual test flow:
   ```
   rails server
   ```
   - Go to http://localhost:3000/login
   - Click "Forgot your password?"
   - Enter an existing user's email
   - Check `rails console` for the sent email: `ActionMailer::Base.deliveries.last`
   - Copy the reset URL from the email body
   - Visit the reset URL, set a new password
   - Log in with the new password

## Post-Merge Deployment Steps

1. Run migration on Heroku:
   ```
   heroku run rails db:migrate --app stay-in-touch-cs396
   ```

2. Set missing SMTP config vars (if not already set):
   ```
   heroku config:set SMTP_PASSWORD='<gmail-app-password>' --app stay-in-touch-cs396
   heroku config:set MAILER_FROM='stayintouchnu@gmail.com' --app stay-in-touch-cs396
   ```

3. Fix the hardcoded production host in `config/environments/production.rb` line 73:
   Change `rocky-cove-15980-acbcac59777d.herokuapp.com` to `stay-in-touch-cs396.herokuapp.com`

4. Test the full flow on production
