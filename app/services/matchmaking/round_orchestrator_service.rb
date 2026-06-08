module Matchmaking
  # Runs ONE matchmaking round for a single requester: builds the candidate pool,
  # has the requester's secretary pick a target + pitch, has the target's secretary
  # decide, records a MeetingProposal, and (on acceptance) creates a calendar event
  # when at least one party has Google Calendar connected. Owns all persistence; the
  # LLM-calling services stay side-effect free. Returns the proposal, or nil when no
  # proposal was made.
  class RoundOrchestratorService
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

      if proposal.accepted?
        if proposal.requester.google_calendar_connected? || proposal.recipient&.google_calendar_connected?
          CreateSchedulingNegotiationJob.perform_later(proposal.id)
        end
      end
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
      blocked_ids  = @requester.blocked_users.pluck(:id)
      blocking_ids = Block.where(blocked: @requester).pluck(:blocker_id)
      excluded_ids = (blocked_ids + blocking_ids + [ @requester.id ]).uniq

      User.matchmaking_candidates
          .where.not(id: excluded_ids)
          .reject { |candidate| MeetingProposal.recently_proposed_between?(@requester, candidate) }
    end
  end
end
