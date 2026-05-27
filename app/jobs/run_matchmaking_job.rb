# Runs a matchmaking round. With no argument it processes every opted-in user
# (the daily batch); with a user_id it runs a single user (the "Run now" button).
# Per-user failures are logged and skipped so one bad round never aborts the batch.
class RunMatchmakingJob < ApplicationJob
  queue_as :default

  def perform(user_id = nil)
    return if ENV["OPENROUTER_API_KEY"].blank?

    scope = user_id ? User.where(id: user_id) : User.matchmaking_candidates
    scope.find_each do |requester|
      next unless requester.matchmaking_ready?

      begin
        Matchmaking::RoundOrchestratorService.new(requester).call
      rescue StandardError => e
        Rails.logger.warn("Matchmaking failed for user #{requester.id}: #{e.message}")
      end
    end
  end
end
