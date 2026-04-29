class GoogleCalendarService
  # Raised when the stored credential is missing or cannot be refreshed.
  class CredentialError < StandardError; end

  def initialize(user)
    @user       = user
    @credential = user.google_credential
    raise CredentialError, "No Google credential for user #{user.id}" unless @credential
  end

  # Pushes a catch-up Event to the user's primary Google Calendar.
  # Returns the created Google::Apis::CalendarV3::Event on success.
  def push_event(event, people)
    service = build_service
    calendar_event = build_calendar_event(event, people)
    service.insert_event("primary", calendar_event)
  end

  private

  def build_service
    auth = Signet::OAuth2::Client.new(
      client_id:            ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret:        ENV.fetch("GOOGLE_CLIENT_SECRET"),
      token_credential_uri: "https://oauth2.googleapis.com/token",
      access_token:         @credential.access_token,
      refresh_token:        @credential.refresh_token,
      expires_at:           @credential.expires_at
    )

    if @credential.expired?
      auth.refresh!
      @credential.update!(
        access_token: auth.access_token,
        expires_at:   Time.at(auth.expires_at.to_i)
      )
    end

    svc = Google::Apis::CalendarV3::CalendarService.new
    svc.authorization = auth
    svc
  end

  def build_calendar_event(event, people)
    # Use the first person's timezone for the event, falling back to UTC.
    tz_name = people.first&.timezone.presence || "UTC"

    start_time = event.occurred_at.in_time_zone(tz_name)
    end_time   = start_time + 1.hour

    attendees = people.filter_map do |p|
      Google::Apis::CalendarV3::EventAttendee.new(email: p.email) if p.email.present?
    end

    Google::Apis::CalendarV3::Event.new(
      summary:     event.display_title,
      description: event.notes.presence,
      start:       Google::Apis::CalendarV3::EventDateTime.new(
                     date_time: start_time.iso8601,
                     time_zone: tz_name
                   ),
      end:         Google::Apis::CalendarV3::EventDateTime.new(
                     date_time: end_time.iso8601,
                     time_zone: tz_name
                   ),
      attendees:   attendees.presence
    )
  end
end
