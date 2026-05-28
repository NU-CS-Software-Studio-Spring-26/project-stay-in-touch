require "rails_helper"

RSpec.describe "Matches (MeetingProposals)", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  before { sign_in(user) }

  describe "GET /matches" do
    it "renders proposals the user is party to" do
      create(:meeting_proposal, requester: user, recipient: other, pitch: "Coffee soon?")
      get matches_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Coffee soon?")
    end

    it "does not show proposals the user is not part of" do
      stranger = create(:user)
      create(:meeting_proposal, requester: other, recipient: stranger, pitch: "Secret pitch")
      get matches_path
      expect(response.body).not_to include("Secret pitch")
    end
  end

  describe "GET /matches/:id" do
    it "shows a proposal the user is part of" do
      proposal = create(:meeting_proposal, requester: user, recipient: other)
      get match_path(proposal)
      expect(response).to have_http_status(:ok)
    end

    it "redirects when the user is not party to the proposal (authorization)" do
      proposal = create(:meeting_proposal, requester: other, recipient: create(:user))
      get match_path(proposal)
      expect(response).to redirect_to(root_path)
    end
  end
end
