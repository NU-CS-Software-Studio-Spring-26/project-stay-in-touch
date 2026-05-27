require "rails_helper"

RSpec.describe MeetingProposal, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:requester).class_name("User") }
    it { is_expected.to belong_to(:recipient).class_name("User") }
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

  describe ".recently_proposed_between?" do
    let(:alice) { create(:user) }
    let(:bob)   { create(:user) }

    it "is true within the recency window" do
      create(:meeting_proposal, requester: alice, recipient: bob, created_at: 1.day.ago)
      expect(described_class.recently_proposed_between?(alice, bob)).to be(true)
    end

    it "is false outside the recency window" do
      create(:meeting_proposal, requester: alice, recipient: bob, created_at: 40.days.ago)
      expect(described_class.recently_proposed_between?(alice, bob)).to be(false)
    end

    it "is direction-specific" do
      create(:meeting_proposal, requester: bob, recipient: alice, created_at: 1.day.ago)
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
  end
end
