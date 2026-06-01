class EventMailer < ApplicationMailer
  def calendar_invite(event, person, organizer)
    @event          = event
    @person         = person
    @organizer      = organizer
    @registered     = person.registered?
    @slot_time      = event.occurred_at.in_time_zone(person.timezone.presence || "UTC")
    @duration_label = format_duration(event.duration_minutes || 60)

    attachments["invite.ics"] = {
      mime_type: "text/calendar; method=REQUEST",
      content:   generate_ical
    }

    mail(
      to:      person.email,
      subject: "Invitation: #{event.display_title} – #{@slot_time.strftime('%B %-d at %-I:%M %p')}"
    )
  end

  private

  def generate_ical
    tz_name     = @person.timezone.presence || "UTC"
    local_start = @event.occurred_at.in_time_zone(tz_name)
    local_end   = local_start + (@event.duration_minutes || 60).minutes
    fmt_local   = "%Y%m%dT%H%M%S"
    fmt_utc     = "%Y%m%dT%H%M%SZ"

    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Serendipity//EN",
      "CALSCALE:GREGORIAN",
      "METHOD:REQUEST",
      "BEGIN:VEVENT",
      "UID:event-#{@event.id}-#{SecureRandom.hex(6)}@serendipity",
      "DTSTAMP:#{Time.now.utc.strftime(fmt_utc)}",
      "DTSTART;TZID=#{tz_name}:#{local_start.strftime(fmt_local)}",
      "DTEND;TZID=#{tz_name}:#{local_end.strftime(fmt_local)}",
      fold_line("SUMMARY:#{@event.display_title}"),
      fold_line("ORGANIZER;CN=\"#{@organizer.email}\":mailto:#{@organizer.email}"),
      fold_line("ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;" \
                "RSVP=TRUE;CN=\"#{@person.name}\":mailto:#{@person.email}"),
      "STATUS:TENTATIVE",
      "SEQUENCE:0",
      "END:VEVENT",
      "END:VCALENDAR"
    ]

    lines.join("\r\n") + "\r\n"
  end

  def format_duration(minutes)
    case minutes.to_i
    when 15  then "15 minutes"
    when 30  then "30 minutes"
    when 45  then "45 minutes"
    when 60  then "1 hour"
    when 90  then "1.5 hours"
    when 120 then "2 hours"
    else          "#{minutes} minutes"
    end
  end

  def fold_line(line)
    return line if line.length <= 75
    result = ""
    while line.length > 75
      result << line[0, 74] << "\r\n "
      line = line[74..]
    end
    result << line
  end
end
