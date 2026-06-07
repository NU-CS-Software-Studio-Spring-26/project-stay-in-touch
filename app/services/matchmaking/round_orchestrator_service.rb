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
      # Configuration / opt-in gates: log but don't record an :error proposal —
      # these aren't per-round failures, they're "this round can't run." The
      # controller already flashes the API-key case, and the Matches page
      # already prompts users who haven't opted in.
      if ENV["OPENROUTER_API_KEY"].blank?
        Rails.logger.warn("RoundOrchestrator: requester=#{@requester.id} skipped — OPENROUTER_API_KEY blank")
        return nil
      end
      unless @requester.matchmaking_ready?
        Rails.logger.warn("RoundOrchestrator: requester=#{@requester.id} skipped — not matchmaking_ready")
        return nil
      end

      candidates = eligible_candidates
      if candidates.empty?
        Rails.logger.warn("RoundOrchestrator: requester=#{@requester.id} has no eligible candidates")
        return record_error("No other opted-in users to pitch right now. Ask a teammate to opt in on Settings.")
      end

      pitch = SecretaryPitchService.new(@requester, candidates).call
      unless pitch
        Rails.logger.warn("RoundOrchestrator: requester=#{@requester.id} got no pitch from SecretaryPitchService")
        return record_error("Your AI couldn't generate an invitation. The AI service was unreachable, " \
                            "rate-limited, or returned unparseable output — see Heroku logs for details.")
      end

      target = pitch.target_user
      unless candidates.include?(target) && target != @requester
        Rails.logger.warn("RoundOrchestrator: requester=#{@requester.id} got invalid target=#{target&.id}")
        return record_error("Your AI picked an invalid target. See Heroku logs for details.")
      end

      review = SecretaryReviewService.new(target, @requester.display_label, pitch.pitch_text).call

      # An "unevaluable" review (AI unreachable/rate-limited/garbled) isn't a real
      # decline — record it as a loud :error (keeping the target + pitch for
      # context) so it's visually distinct from a secretary's genuine "no".
      if review.error
        Rails.logger.warn("RoundOrchestrator: requester=#{@requester.id} review unevaluable for target=#{target.id}")
        return record_review_error(target, pitch.pitch_text, review.reason)
      end

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

    # Record a visible :error proposal so the failure surfaces on the Matches
    # page instead of vanishing. Recipient is nil because we didn't reach the
    # point of picking one (or the one we picked was rejected as invalid).
    def record_error(reason)
      MeetingProposal.create!(
        requester:                  @requester,
        recipient:                  nil,
        status:                     :error,
        decision_reason:            reason,
        requester_profile_snapshot: @requester.meeting_interests
      )
    end

    # Like record_error, but for a round that got far enough to pick a target and
    # write a pitch before the recipient's secretary failed to evaluate it. Keeps
    # the recipient + pitch so the Matches page can show what was attempted.
    def record_review_error(target, pitch_text, reason)
      MeetingProposal.create!(
        requester:                  @requester,
        recipient:                  target,
        status:                     :error,
        pitch:                      pitch_text,
        decision_reason:            reason,
        requester_profile_snapshot: @requester.meeting_interests,
        recipient_profile_snapshot: target.meeting_interests
      )
    end

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
      tz      = ActiveSupport::TimeZone[host.timezone] || Time.zone
      busy    = service.busy_intervals(window_days: SLOT_WINDOW_DAYS)
      start_time = GoogleCalendarService.earliest_free_slot(
        busy:          busy,
        window_days:   SLOT_WINDOW_DAYS,
        from_hour:     SLOT_FROM_HOUR,
        to_hour:       SLOT_TO_HOUR,
        slot_duration: MEETING_DURATION_MINUTES.minutes,
        tz:            tz
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
