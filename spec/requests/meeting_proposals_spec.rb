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

  describe "PATCH /matches/:id/dismiss" do
    it "hides the match from the dismisser's list but leaves it for the other party" do
      proposal = create(:meeting_proposal, requester: user, recipient: other, pitch: "Coffee soon?")

      patch dismiss_match_path(proposal)
      expect(response).to redirect_to(matches_path)

      get matches_path
      expect(response.body).not_to include("Coffee soon?")

      # The other party still sees it.
      sign_in(other)
      get matches_path
      expect(response.body).to include("Coffee soon?")
    end

    it "does not let a non-party dismiss a match" do
      proposal = create(:meeting_proposal, requester: other, recipient: create(:user))
      patch dismiss_match_path(proposal)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /matches/:id/add_to_people" do
    let(:other) { create(:user, display_name: "Casey Jones", email: "casey@example.com") }

    it "adds the other party to the current user's People and redirects to them" do
      proposal = create(:meeting_proposal, requester: user, recipient: other)

      expect { post add_to_people_match_path(proposal) }.to change(user.people, :count).by(1)

      person = user.people.order(:created_at).last
      expect(person.name).to eq("Casey Jones")
      expect(person.email).to eq("casey@example.com")
      expect(response).to redirect_to(person_path(person))
    end

    it "does not create a duplicate when they're already in People" do
      proposal = create(:meeting_proposal, requester: user, recipient: other)
      existing = create(:person, user: user, email: "casey@example.com")

      expect { post add_to_people_match_path(proposal) }.not_to change(Person, :count)
      expect(response).to redirect_to(person_path(existing))
    end

    it "does not let a non-party add from a match" do
      proposal = create(:meeting_proposal, requester: other, recipient: create(:user))
      expect { post add_to_people_match_path(proposal) }.not_to change(Person, :count)
      expect(response).to redirect_to(root_path)
    end
  end
end
