require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /settings/edit" do
    it "renders the matchmaking profile fields" do
      get edit_settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("meeting_interests")
      expect(response.body).to include("matchmaking_enabled")
    end
  end

  describe "PATCH /settings" do
    it "updates the matchmaking profile fields" do
      patch settings_path, params: { user: {
        display_name:        "Jordan",
        meeting_interests:   "Looking for design feedback",
        matchmaking_enabled: "1"
      } }

      user.reload
      expect(user.display_name).to eq("Jordan")
      expect(user.meeting_interests).to eq("Looking for design feedback")
      expect(user.matchmaking_enabled).to be(true)
      expect(response).to redirect_to(edit_settings_path)
    end
  end
end
