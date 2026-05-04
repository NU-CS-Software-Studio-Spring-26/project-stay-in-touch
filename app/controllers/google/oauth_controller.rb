require "net/http"
require "json"

module Google
  class OauthController < ApplicationController
    allow_unauthenticated_access only: [ :authorize, :callback ]

    CALENDAR_SCOPES = %w[https://www.googleapis.com/auth/calendar.events].freeze
    SIGNIN_SCOPES   = %w[openid
                         https://www.googleapis.com/auth/userinfo.email
                         https://www.googleapis.com/auth/userinfo.profile].freeze

    # GET /google/oauth/authorize
    # Accepts ?mode=signin from the login/signup pages; defaults to calendar mode.
    def authorize
      signin = params[:mode] == "signin"

      unless signin || authenticated?
        redirect_to login_path, alert: "Please log in first."
        return
      end

      client = build_client(signin ? SIGNIN_SCOPES : CALENDAR_SCOPES)
      client.update!(additional_parameters: {
        access_type: "offline",
        prompt:      "consent",
        state:       signin ? "signin" : "calendar"
      })
      redirect_to client.authorization_uri.to_s, allow_other_host: true
    end

    # GET /google/oauth/callback
    def callback
      if params[:state] == "signin"
        handle_signin
      else
        handle_calendar
      end
    end

    # DELETE /google/oauth
    def destroy
      current_user.google_credential&.destroy
      redirect_to people_path, notice: "Google Calendar disconnected."
    end

    private

    # ── Sign-in flow ──────────────────────────────────────────────────────────

    def handle_signin
      if params[:error].present?
        redirect_to login_path, alert: "Google sign-in was cancelled."
        return
      end

      client = build_client(SIGNIN_SCOPES)
      client.code = params[:code]
      client.fetch_access_token!

      info = google_userinfo(client.access_token)

      unless info["email_verified"]
        redirect_to login_path, alert: "Your Google account email is not verified."
        return
      end

      user = User.find_by(email: info["email"].downcase) || create_google_user(info["email"])
      start_new_session_for(user)
      redirect_to root_path, notice: "Signed in with Google."
    end

    def create_google_user(email)
      random_pw = SecureRandom.hex(32)
      user = User.new(email: email, password: random_pw, password_confirmation: random_pw)
      user.skip_password_complexity = true
      user.save!
      user
    end

    def google_userinfo(access_token)
      uri = URI("https://www.googleapis.com/oauth2/v3/userinfo")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.get(uri.path, "Authorization" => "Bearer #{access_token}")
      end
      JSON.parse(response.body)
    end

    # ── Calendar connection flow ───────────────────────────────────────────────

    def handle_calendar
      unless authenticated?
        redirect_to login_path, alert: "Please log in first."
        return
      end

      if params[:error].present?
        redirect_to people_path, alert: "Google Calendar connection was denied."
        return
      end

      client = build_client(CALENDAR_SCOPES)
      client.code = params[:code]
      client.fetch_access_token!

      current_user.create_or_update_google_credential!(
        access_token:  client.access_token,
        refresh_token: client.refresh_token,
        expires_at:    Time.at(client.expires_at.to_i)
      )

      redirect_to people_path, notice: "Google Calendar connected successfully."
    end

    # ── Shared ─────────────────────────────────────────────────────────────────

    def build_client(scopes)
      Signet::OAuth2::Client.new(
        client_id:            ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret:        ENV.fetch("GOOGLE_CLIENT_SECRET"),
        redirect_uri:         ENV.fetch("GOOGLE_REDIRECT_URI"),
        authorization_uri:    "https://accounts.google.com/o/oauth2/auth",
        token_credential_uri: "https://oauth2.googleapis.com/token",
        scope:                scopes
      )
    end
  end
end
