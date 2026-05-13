class EventMailer < ApplicationMailer
  def calendar_invite(event, person, organizer)
    @event     = event
    @person    = person
    @organizer = organizer
    @slot_time = event.occurred_at.in_time_zone(person.timezone.presence || "UTC")

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
    start_utc = @event.occurred_at.utc
    end_utc   = (@event.occurred_at + 30.minutes).utc
    fmt       = "%Y%m%dT%H%M%SZ"

    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Stay In Touch//EN",
      "CALSCALE:GREGORIAN",
      "METHOD:REQUEST",
      "BEGIN:VEVENT",
      "UID:event-#{@event.id}-#{SecureRandom.hex(6)}@stayintouch",
      "DTSTAMP:#{Time.now.utc.strftime(fmt)}",
      "DTSTART:#{start_utc.strftime(fmt)}",
      "DTEND:#{end_utc.strftime(fmt)}",
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
