require "rails_helper"

RSpec.describe MeetingProposal, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:requester).class_name("User") }
    it { is_expected.to belong_to(:recipient).class_name("User").optional }
  end

  describe "status enum" do
    it {
      is_expected.to define_enum_for(:status)
        .with_values(pending: 0, accepted: 1, declined: 2, error: 3)
    }
  end

  describe "validations" do
    it "is invalid when requester and recipient are the same user" do
      user = create(:user)
      proposal = build(:meeting_proposal, requester: user, recipient: user)
      expect(proposal).not_to be_valid
      expect(proposal.errors[:recipient_id]).to be_present
    end

    it "allows recipient to be nil (used by :error rows for failed rounds)" do
      proposal = build(:meeting_proposal, requester: create(:user), recipient: nil, status: :error)
      expect(proposal).to be_valid
    end
  end

  describe ".for_user" do
    let(:alice) { create(:user) }
    let(:bob)   { create(:user) }
    let(:carol) { create(:user) }

    it "returns proposals on either side, excluding unrelated ones" do
      as_requester = create(:meeting_proposal, requester: alice, recipient: bob)
      as_recipient = create(:meeting_proposal, requester: bob, recipient: alice)
      unrelated    = create(:meeting_proposal, requester: bob, recipient: carol)

      result = described_class.for_user(alice)
      expect(result).to include(as_requester, as_recipient)
      expect(result).not_to include(unrelated)
    end
  end

  describe ".visible_to and #dismiss_for" do
    let(:alice) { create(:user) }
    let(:bob)   { create(:user) }

    it "hides a match from the dismisser but keeps it for the other party" do
      proposal = create(:meeting_proposal, requester: alice, recipient: bob)

      proposal.dismiss_for(alice)

      expect(described_class.visible_to(alice)).not_to include(proposal)
      expect(described_class.visible_to(bob)).to include(proposal)
    end

    it "is per-side: the requester dismissing doesn't touch the recipient's flag" do
      proposal = create(:meeting_proposal, requester: alice, recipient: bob)

      proposal.dismiss_for(alice)

      expect(proposal.requester_dismissed_at).to be_present
      expect(proposal.recipient_dismissed_at).to be_nil
    end

    it "still authorizes — only returns proposals the user is party to" do
      mine      = create(:meeting_proposal, requester: alice, recipient: bob)
      unrelated = create(:meeting_proposal, requester: bob, recipient: create(:user))

      expect(described_class.visible_to(alice)).to include(mine)
      expect(described_class.visible_to(alice)).not_to include(unrelated)
    end
  end

  describe ".recently_proposed_between?" do
    let(:alice) { create(:user) }
    let(:bob)   { create(:user) }

    # Anchor times to the constant so these stay correct whatever RECENCY_WINDOW is
    # set to (10 seconds in dev, longer in prod).
    let(:within_window)  { (described_class::RECENCY_WINDOW / 2).ago }
    let(:outside_window) { (described_class::RECENCY_WINDOW * 2 + 1.hour).ago }

    it "is true within the recency window" do
      create(:meeting_proposal, requester: alice, recipient: bob, created_at: within_window)
      expect(described_class.recently_proposed_between?(alice, bob)).to be(true)
    end

    it "is false outside the recency window" do
      create(:meeting_proposal, requester: alice, recipient: bob, created_at: outside_window)
      expect(described_class.recently_proposed_between?(alice, bob)).to be(false)
    end

    it "is direction-specific" do
      create(:meeting_proposal, requester: bob, recipient: alice, created_at: within_window)
      expect(described_class.recently_proposed_between?(alice, bob)).to be(false)
    end

    it "ignores :error rows (a failed round shouldn't block a real retry)" do
      create(:meeting_proposal, requester: alice, recipient: bob,
                                status: :error, created_at: within_window)
      expect(described_class.recently_proposed_between?(alice, bob)).to be(false)
    end
  end

  describe "#other_party" do
    let(:alice)    { create(:user) }
    let(:bob)      { create(:user) }
    let(:proposal) { create(:meeting_proposal, requester: alice, recipient: bob) }

    it "returns the recipient for the requester" do
      expect(proposal.other_party(alice)).to eq(bob)
    end

    it "returns the requester for the recipient" do
      expect(proposal.other_party(bob)).to eq(alice)
    end

    it "returns nil when called by the requester of a recipient-less :error row" do
      error_row = create(:meeting_proposal, requester: alice, recipient: nil, status: :error)
      expect(error_row.other_party(alice)).to be_nil
    end
  end
end
