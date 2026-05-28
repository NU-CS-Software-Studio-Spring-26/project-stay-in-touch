# Manually triggers a matchmaking round for the current user (the "Run matchmaking
# now" button). The daily batch runs via the matchmaking:run rake task instead.
class MatchmakingController < ApplicationController
  def create
    if ENV["OPENROUTER_API_KEY"].blank?
      redirect_to matches_path, alert: "Matchmaking is unavailable — AI is not configured."
      return
    end

    unless current_user.matchmaking_ready?
      redirect_to edit_settings_path,
                  alert: "Add your meeting interests and enable matchmaking first."
      return
    end

    RunMatchmakingJob.perform_later(current_user.id)
    redirect_to matches_path,
                notice: "Your AI secretary is reaching out… refresh in a moment to see the result."
  end
end
