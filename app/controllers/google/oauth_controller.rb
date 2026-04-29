module Google
  class OauthController < ApplicationController
    SCOPES = %w[https://www.googleapis.com/auth/calendar.events].freeze

    # GET /auth/google — redirect the browser to Google's consent screen
    def authorize
      client = oauth_client
      client.update!(
        additional_parameters: { access_type: "offline", prompt: "consent" }
      )
      redirect_to client.authorization_uri.to_s, allow_other_host: true
    end

    # GET /auth/google/callback — exchange code for tokens, persist credential
    def callback
      if params[:error].present?
        redirect_to people_path, alert: "Google Calendar connection was denied."
        return
      end

      client = oauth_client
      client.code = params[:code]
      client.fetch_access_token!

      current_user.create_or_update_google_credential!(
        access_token:  client.access_token,
        refresh_token: client.refresh_token,
        expires_at:    Time.at(client.expires_at.to_i)
      )

      redirect_to people_path, notice: "Google Calendar connected successfully."
    end

    # DELETE /auth/google — remove the stored credential
    def destroy
      current_user.google_credential&.destroy
      redirect_to people_path, notice: "Google Calendar disconnected."
    end

    private

    def oauth_client
      Signet::OAuth2::Client.new(
        client_id:             ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret:         ENV.fetch("GOOGLE_CLIENT_SECRET"),
        redirect_uri:          ENV.fetch("GOOGLE_REDIRECT_URI"),
        authorization_uri:     "https://accounts.google.com/o/oauth2/auth",
        token_credential_uri:  "https://oauth2.googleapis.com/token",
        scope:                 SCOPES
      )
    end
  end
end
