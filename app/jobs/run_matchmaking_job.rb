# Runs a matchmaking round. With no argument it processes every opted-in user
# (the daily batch); with a user_id it runs a single user (the "Run now" button).
# Per-user failures are logged and skipped so one bad round never aborts the batch.
class RunMatchmakingJob < ApplicationJob
  queue_as :default

  # Gap between rounds in the daily batch so opted-in users aren't all fired at
  # the model back-to-back. (Each round also retries on 429 internally.)
  BATCH_PAUSE_SECONDS = 3

  def perform(user_id = nil)
    return if ENV["OPENROUTER_API_KEY"].blank?

    scope = user_id ? User.where(id: user_id) : User.matchmaking_candidates
    batch = user_id.nil?
    processed_any = false

    scope.find_each do |requester|
      next unless requester.matchmaking_ready?

      OpenRouterChat.pause(BATCH_PAUSE_SECONDS) if batch && processed_any
      processed_any = true

      begin
        Matchmaking::RoundOrchestratorService.new(requester).call
      rescue StandardError => e
        Rails.logger.error("RunMatchmakingJob: requester=#{requester.id} raised #{e.class}: #{e.message}")
        # Surface the failure on the user's Matches page so they don't just see
        # nothing happen. The orchestrator already records :error rows for its
        # own controlled-nil paths; this catches whatever it missed.
        MeetingProposal.create!(
          requester:                  requester,
          recipient:                  nil,
          status:                     :error,
          decision_reason:            "Matchmaking failed unexpectedly (#{e.class}). See Heroku logs for details.",
          requester_profile_snapshot: requester.meeting_interests
        )
      end
    end
  end
end
