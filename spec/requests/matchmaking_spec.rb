require "rails_helper"

RSpec.describe "Matchmaking", type: :request do
  let(:user) { create(:user, :matchmaking_ready) }

  before { sign_in(user) }

  describe "POST /matchmaking/run" do
    context "when the API key is absent" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return(nil)
      end

      it "redirects to matches with an alert and does not enqueue" do
        expect(RunMatchmakingJob).not_to receive(:perform_later)
        post run_matchmaking_path
        expect(response).to redirect_to(matches_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when configured but the user is not matchmaking-ready" do
      let(:user) { create(:user, matchmaking_enabled: false) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return("test-key")
      end

      it "redirects to settings without enqueuing" do
        expect(RunMatchmakingJob).not_to receive(:perform_later)
        post run_matchmaking_path
        expect(response).to redirect_to(edit_settings_path)
      end
    end

    context "when ready and configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return("test-key")
      end

      it "enqueues the job for the current user and redirects to matches" do
        expect(RunMatchmakingJob).to receive(:perform_later).with(user.id)
        post run_matchmaking_path
        expect(response).to redirect_to(matches_path)
        expect(flash[:notice]).to be_present
      end
    end
  end
end
