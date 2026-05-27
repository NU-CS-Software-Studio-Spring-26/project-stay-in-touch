module Matchmaking
  # Runs ONE matchmaking round for a single requester: builds the candidate pool,
  # has the requester's secretary pick a target + pitch, has the target's secretary
  # decide, records a MeetingProposal, and (on acceptance) creates a calendar event
  # when at least one party has Google Calendar connected. Owns all persistence; the
  # LLM-calling services stay side-effect free. Returns the proposal, or nil when no
  # proposal was made.
  class RoundOrchestratorService
    SLOT_WINDOW_DAYS         = 7
    SLOT_FROM_HOUR           = 9
    SLOT_TO_HOUR             = 17
    MEETING_DURATION_MINUTES = 30

    def initialize(requester)
      @requester = requester
    end

    def call
      return nil if ENV["OPENROUTER_API_KEY"].blank?
      return nil unless @requester.matchmaking_ready?

      candidates = eligible_candidates
      return nil if candidates.empty?

      pitch = SecretaryPitchService.new(@requester, candidates).call
      return nil unless pitch

      target = pitch.target_user
      return nil unless candidates.include?(target) && target != @requester

      review = SecretaryReviewService.new(target, @requester.display_label, pitch.pitch_text).call

      proposal = MeetingProposal.create!(
        requester:                  @requester,
        recipient:                  target,
        status:                     review.accepted ? :accepted : :declined,
        pitch:                      pitch.pitch_text,
        decision_reason:            review.reason,
        requester_profile_snapshot: @requester.meeting_interests,
        recipient_profile_snapshot: target.meeting_interests
      )

      create_calendar_event(proposal) if proposal.accepted?
      proposal
    end

    private

    # Opted-in users other than the requester, excluding pairs proposed recently.
    def eligible_candidates
      User.matchmaking_candidates
          .where.not(id: @requester.id)
          .reject { |candidate| MeetingProposal.recently_proposed_between?(@requester, candidate) }
    end

    # Mirrors the existing event flow: the connected party hosts (their calendar is
    # checked and the event lands on it); the other is added purely as an attendee
    # email. Only the host needs Google connected. Record-only fallback on any error.
    def create_calendar_event(proposal)
      host  = proposal.requester.google_calendar_connected? ? proposal.requester : proposal.recipient
      return unless host.google_calendar_connected?

      guest   = proposal.other_party(host)
      service = GoogleCalendarService.new(host)
      start_time = service.find_earliest_slot(
        window_days:   SLOT_WINDOW_DAYS,
        from_hour:     SLOT_FROM_HOUR,
        to_hour:       SLOT_TO_HOUR,
        slot_duration: MEETING_DURATION_MINUTES.minutes
      ) || default_slot(host)

      event = service.push_user_meeting(
        summary:          "Intro: #{proposal.requester.display_label} & #{proposal.recipient.display_label}",
        description:      proposal.pitch,
        start_time:       start_time,
        duration_minutes: MEETING_DURATION_MINUTES,
        attendee_emails:  [guest.email],
        tz_name:          host.timezone
      )

      proposal.update!(
        meeting_at:          start_time,
        calendar_event_id:   event.id,
        calendar_event_link: event.html_link,
        calendar_created:    true
      )
    rescue StandardError => e
      Rails.logger.warn("Matchmaking calendar event failed for proposal #{proposal.id}: #{e.message}")
    end

    def default_slot(host)
      tz = ActiveSupport::TimeZone[host.timezone] || Time.zone
      tz.now.tomorrow.change(hour: 10).utc
    end
  end
end
