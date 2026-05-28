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

  # Pushes a User<->User meeting to this user's primary Google Calendar, adding the
  # other party as an attendee by email (they need no account or connected calendar).
  # Built from primitives so it stays decoupled from the Event/Person models, which
  # the matchmaking feature does not use. Returns the created Google event.
  def push_user_meeting(summary:, start_time:, description: nil, attendee_emails: [],
                        duration_minutes: 30, tz_name: "UTC")
    service = build_service
    start_t = start_time.in_time_zone(tz_name)
    end_t   = start_t + duration_minutes.minutes

    attendees = attendee_emails.compact_blank.map do |email|
      Google::Apis::CalendarV3::EventAttendee.new(email: email)
    end

    calendar_event = Google::Apis::CalendarV3::Event.new(
      summary:     summary,
      description: description.presence,
      start:       Google::Apis::CalendarV3::EventDateTime.new(
                     date_time: start_t.iso8601,
                     time_zone: tz_name
                   ),
      end:         Google::Apis::CalendarV3::EventDateTime.new(
                     date_time: end_t.iso8601,
                     time_zone: tz_name
                   ),
      attendees:   attendees.presence
    )

    service.insert_event("primary", calendar_event)
  end

  # Returns busy [start, end] Time pairs for the user's primary calendar on a given date.
  def busy_for_day(date, tz)
    service  = build_service
    time_min = tz.local(date.year, date.month, date.day, 0, 0).iso8601
    time_max = tz.local(date.year, date.month, date.day, 23, 59, 59).iso8601

    result = service.list_events(
      "primary",
      time_min:      time_min,
      time_max:      time_max,
      single_events: true,
      order_by:      "startTime"
    )

    (result.items || []).filter_map do |ev|
      next if ev.start.nil? || ev.end.nil?
      s = ev.start.date_time || Time.parse(ev.start.date.to_s)
      e = ev.end.date_time   || Time.parse(ev.end.date.to_s)
      [s, e]
    end
  rescue StandardError
    []
  end

  # Returns busy [start, end] Time pairs for the user's primary calendar over
  # the next window_days days. Returns [] if the free/busy query fails, so a
  # caller merging several users' calendars degrades gracefully per-user.
  def busy_intervals(window_days:)
    service    = build_service
    now        = Time.current
    window_end = now + window_days.days

    request = Google::Apis::CalendarV3::FreeBusyRequest.new(
      time_min: now.iso8601,
      time_max: window_end.iso8601,
      items:    [{ id: "primary" }]
    )
    response = service.query_freebusy(request)
    cal = response.calendars["primary"] || response.calendars.values.first
    (cal && !cal.errors&.any?) ? cal.busy.map { |s| [s.start, s.end] } : []
  rescue StandardError => e
    Rails.logger.warn("busy_intervals failed: #{e.message}")
    []
  end

  # Finds the earliest free slot_duration slot within the next window_days days,
  # restricted to hours [from_hour, to_hour) in tz, that avoids every interval in
  # busy (each a [start, end] pair) plus a buffer on either side. Pure function:
  # the caller passes the merged busy intervals from however many calendars it
  # wants considered (e.g. organizer + registered invitees). Returns a Time or nil.
  def self.earliest_free_slot(busy:, window_days:, from_hour:, to_hour:,
                              slot_duration: 60.minutes, buffer: 15.minutes,
                              tz: Time.zone, now: Time.current)
    window_end = now + window_days.days
    cursor     = now.ceil(15.minutes)

    while cursor + slot_duration <= window_end
      local = cursor.in_time_zone(tz)
      if local.hour >= from_hour && local.hour < to_hour
        slot_end = cursor + slot_duration
        free = busy.none? { |s, e| cursor < e + buffer && slot_end > s - buffer }
        return cursor if free
      end
      cursor += 15.minutes
    end

    nil
  end

  # Returns up to max_slots suggested 30-min meeting start times (as TimeWithZone in
  # person's timezone) that are free on both the user's and person's calendar and fall
  # within the person's preferred hours.
  def suggest_times(person, days_ahead: 7, max_slots: 5)
    service   = build_service
    now       = Time.now.utc
    window_end = (now + days_ahead.days)

    request = Google::Apis::CalendarV3::FreeBusyRequest.new(
      time_min: now.iso8601,
      time_max: window_end.iso8601,
      items:    [ { id: "primary" }, { id: person.email } ]
    )
    response = service.query_freebusy(request)

    busy = []
    response.calendars.each_value do |cal|
      next if cal.errors&.any?
      cal.busy.each do |slot|
        busy << [ slot.start, slot.end ]
      end
    end

    busy.sort_by!(&:first)
    merged = busy.each_with_object([]) do |(s, e), acc|
      if acc.empty? || s > acc.last[1]
        acc << [ s, e ]
      else
        acc.last[1] = [ acc.last[1], e ].max
      end
    end

    tz       = person.timezone
    start_h  = person.preferred_start_hour
    end_h    = person.preferred_end_hour
    duration = 30.minutes
    cursor   = now.ceil(30.minutes)
    slots    = []

    while cursor + duration <= window_end && slots.size < max_slots
      local = cursor.in_time_zone(tz)
      if local.hour >= start_h && local.hour < end_h
        slot_end   = cursor + duration
        overlaps   = merged.any? { |s, e| cursor < e && slot_end > s }
        slots << local unless overlaps
      end
      cursor += duration
    end

    slots
  rescue StandardError
    []
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
    tz_name  = people.first&.timezone.presence || "UTC"
    duration = (event.duration_minutes.presence || 60).minutes

    start_time = event.occurred_at.in_time_zone(tz_name)
    end_time   = start_time + duration

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
