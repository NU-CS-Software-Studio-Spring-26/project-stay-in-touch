# Runs a matchmaking round. With no argument it processes every opted-in user
# (the daily batch); with a user_id it runs a single user (the "Run now" button).
# Per-user failures are logged and skipped so one bad round never aborts the batch.
class RunMatchmakingJob < ApplicationJob
  queue_as :default

  # Gap between rounds in the daily batch so opted-in users aren't all fired at
  # the free model back-to-back. (Each round also retries on 429 internally.)
  BATCH_PAUSE_SECONDS = 3

  def perform(user_id = nil)
    return if ENV["OPENROUTER_API_KEY"].blank?

    scope = user_id ? User.where(id: user_id) : User.matchmaking_candidates
    batch = user_id.nil?
    processed_any = false

    scope.find_each do |requester|
      next unless requester.matchmaking_ready?

      Matchmaking::RateLimitedChat.pause(BATCH_PAUSE_SECONDS) if batch && processed_any
      processed_any = true

      begin
        Matchmaking::RoundOrchestratorService.new(requester).call
      rescue StandardError => e
        Rails.logger.warn("Matchmaking failed for user #{requester.id}: #{e.message}")
      end
    end
  end
end
