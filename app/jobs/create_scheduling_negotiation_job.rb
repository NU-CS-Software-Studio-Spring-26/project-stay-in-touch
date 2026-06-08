class CreateSchedulingNegotiationJob < ApplicationJob
  queue_as :default

  SLOT_COUNT   = 5
  WINDOW_DAYS  = 7
  FROM_HOUR    = 9
  TO_HOUR      = 17
  DURATION     = 30.minutes

  def perform(proposal_id)
    proposal = MeetingProposal.find_by(id: proposal_id)
    return unless proposal&.accepted?
    return if proposal.scheduling_negotiation.present?

    slots = find_free_slots(proposal)

    negotiation = SchedulingNegotiation.create!(
      meeting_proposal: proposal,
      expires_at:       48.hours.from_now
    )

    slots.each { |t| negotiation.scheduling_slots.create!(starts_at: t) }

    proposal.parties.each do |party|
      SchedulingMailer.invite(negotiation, party).deliver_later
    end
  end

  private

  def find_free_slots(proposal)
    busy   = merged_busy(proposal)
    slots  = []
    cursor = Time.current

    SLOT_COUNT.times do
      t = GoogleCalendarService.earliest_free_slot(
        busy:          busy,
        window_days:   WINDOW_DAYS,
        from_hour:     FROM_HOUR,
        to_hour:       TO_HOUR,
        slot_duration: DURATION,
        now:           cursor
      )
      break unless t
      slots  << t
      cursor  = t + DURATION
    end

    return slots unless slots.empty?

    base = default_start(proposal.requester)
    SLOT_COUNT.times.map { |i| base + (i * 2).hours }
  end

  def merged_busy(proposal)
    raw = []
    proposal.parties.each do |user|
      next unless user.google_calendar_connected?
      svc  = GoogleCalendarService.new(user)
      raw += svc.busy_intervals(window_days: WINDOW_DAYS)
    rescue StandardError => e
      Rails.logger.warn("CreateSchedulingNegotiationJob: busy_intervals for user #{user.id}: #{e.message}")
    end

    raw.sort_by!(&:first)
    raw.each_with_object([]) do |(s, e), acc|
      if acc.empty? || s > acc.last[1]
        acc << [s, e]
      else
        acc.last[1] = [acc.last[1], e].max
      end
    end
  end

  def default_start(user)
    tz = ActiveSupport::TimeZone[user.timezone] || Time.zone
    tz.now.tomorrow.change(hour: 10).utc
  end
end
