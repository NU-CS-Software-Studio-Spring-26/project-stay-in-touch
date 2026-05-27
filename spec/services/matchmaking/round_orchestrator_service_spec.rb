require "rails_helper"

RSpec.describe Matchmaking::RoundOrchestratorService, type: :service do
  let(:requester) { create(:user, :matchmaking_ready) }
  let(:target)    { create(:user, :matchmaking_ready) }

  subject(:service) { described_class.new(requester) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return("test-key")
    target # ensure a persisted, eligible candidate exists
  end

  def stub_pitch(result)
    pitch_service = instance_double(Matchmaking::SecretaryPitchService, call: result)
    allow(Matchmaking::SecretaryPitchService).to receive(:new).and_return(pitch_service)
  end

  def stub_review(accepted:, reason: "because")
    review = Matchmaking::SecretaryReviewService::ReviewResult.new(accepted: accepted, reason: reason)
    review_service = instance_double(Matchmaking::SecretaryReviewService, call: review)
    allow(Matchmaking::SecretaryReviewService).to receive(:new).and_return(review_service)
  end

  def pitch_for(user)
    Matchmaking::SecretaryPitchService::PitchResult.new(user, "Let's meet")
  end

  describe "#call" do
    context "when neither party has Google connected" do
      it "creates an accepted proposal with no calendar event" do
        stub_pitch(pitch_for(target))
        stub_review(accepted: true)

        expect { service.call }.to change(MeetingProposal, :count).by(1)

        proposal = MeetingProposal.last
        expect(proposal).to be_accepted
        expect(proposal.calendar_created).to be(false)
        expect(proposal.requester).to eq(requester)
        expect(proposal.recipient).to eq(target)
      end

      it "snapshots both profiles at proposal time" do
        stub_pitch(pitch_for(target))
        stub_review(accepted: true)
        service.call

        proposal = MeetingProposal.last
        expect(proposal.requester_profile_snapshot).to eq(requester.meeting_interests)
        expect(proposal.recipient_profile_snapshot).to eq(target.meeting_interests)
      end

      it "creates a declined proposal and never touches the calendar" do
        stub_pitch(pitch_for(target))
        stub_review(accepted: false, reason: "nope")
        expect(GoogleCalendarService).not_to receive(:new)

        service.call
        expect(MeetingProposal.last).to be_declined
      end
    end

    context "when the requester has Google connected" do
      let(:calendar)   { instance_double(GoogleCalendarService) }
      let(:gcal_event) { double("gcal_event", id: "evt-1", html_link: "https://cal/evt-1") }

      before do
        create(:google_credential, user: requester)
        stub_pitch(pitch_for(target))
        stub_review(accepted: true)
        allow(GoogleCalendarService).to receive(:new).with(requester).and_return(calendar)
        allow(calendar).to receive(:find_earliest_slot).and_return(Time.utc(2026, 6, 1, 15, 0))
        allow(calendar).to receive(:push_user_meeting).and_return(gcal_event)
      end

      it "hosts on the requester, adds the recipient as attendee, and records the event" do
        expect(calendar).to receive(:push_user_meeting)
          .with(hash_including(attendee_emails: [target.email]))
          .and_return(gcal_event)

        service.call

        proposal = MeetingProposal.last
        expect(proposal.calendar_created).to be(true)
        expect(proposal.calendar_event_id).to eq("evt-1")
        expect(proposal.calendar_event_link).to eq("https://cal/evt-1")
      end
    end

    context "when only the recipient has Google connected" do
      let(:calendar)   { instance_double(GoogleCalendarService) }
      let(:gcal_event) { double("gcal_event", id: "evt-2", html_link: "https://cal/evt-2") }

      before do
        create(:google_credential, user: target)
        stub_pitch(pitch_for(target))
        stub_review(accepted: true)
        allow(GoogleCalendarService).to receive(:new).with(target).and_return(calendar)
        allow(calendar).to receive(:find_earliest_slot).and_return(nil) # falls back to default slot
        allow(calendar).to receive(:push_user_meeting).and_return(gcal_event)
      end

      it "hosts on the recipient and adds the requester as attendee" do
        expect(calendar).to receive(:push_user_meeting)
          .with(hash_including(attendee_emails: [requester.email]))
          .and_return(gcal_event)

        service.call
        expect(MeetingProposal.last.calendar_created).to be(true)
      end
    end

    context "guards" do
      it "returns nil when the API key is absent" do
        allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return(nil)
        expect(service.call).to be_nil
        expect(MeetingProposal.count).to eq(0)
      end

      it "returns nil when the requester is not matchmaking-ready" do
        requester.update!(matchmaking_enabled: false)
        expect(service.call).to be_nil
      end

      it "returns nil when there are no eligible candidates" do
        target.update!(matchmaking_enabled: false)
        expect(service.call).to be_nil
      end

      it "returns nil when the pitch service yields nothing" do
        stub_pitch(nil)
        expect(service.call).to be_nil
      end

      it "skips candidates proposed within the recency window" do
        create(:meeting_proposal, requester: requester, recipient: target, created_at: 1.day.ago)
        expect(service.call).to be_nil
        expect(MeetingProposal.count).to eq(1) # only the pre-existing one; no new proposal
      end
    end
  end
end
