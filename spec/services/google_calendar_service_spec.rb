require "rails_helper"

RSpec.describe GoogleCalendarService, type: :service do
  let(:user)       { create(:user) }
  let(:credential) { create(:google_credential, user: user) }
  let(:person)     { create(:person, user: user, email: "alice@example.com", timezone: "America/New_York") }
  let(:event)      { create(:event, user: user, title: "Coffee chat", medium: "coffee", occurred_at: Time.zone.parse("2026-05-01 10:00:00")) }
  let(:people)     { [person] }

  before do
    credential # ensure the credential is persisted
    stub_env_vars
  end

  subject(:service) { described_class.new(user) }

  describe "#initialize" do
    context "when the user has no Google credential" do
      it "raises CredentialError" do
        user_without_cred = create(:user)
        expect { described_class.new(user_without_cred) }
          .to raise_error(GoogleCalendarService::CredentialError, /No Google credential/)
      end
    end

    context "when the user has a credential" do
      it "does not raise" do
        expect { service }.not_to raise_error
      end
    end
  end

  describe "#push_event" do
    let(:calendar_service_double) { instance_double(Google::Apis::CalendarV3::CalendarService) }
    let(:auth_double)             { instance_double(Signet::OAuth2::Client) }

    before do
      allow(Signet::OAuth2::Client).to receive(:new).and_return(auth_double)
      allow(auth_double).to receive(:refresh!)
      allow(auth_double).to receive(:access_token).and_return("new-access-token")
      allow(auth_double).to receive(:expires_at).and_return(1.hour.from_now.to_i)
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(calendar_service_double)
      allow(calendar_service_double).to receive(:authorization=)
      allow(calendar_service_double).to receive(:insert_event).and_return(double("gcal_event", id: "google-event-123"))
    end

    context "when the credential is still valid (not expired)" do
      before { credential.update!(expires_at: 1.hour.from_now) }

      it "does not call refresh!" do
        expect(auth_double).not_to receive(:refresh!)
        service.push_event(event, people)
      end

      it "calls insert_event on the calendar service" do
        expect(calendar_service_double).to receive(:insert_event).with("primary", anything)
        service.push_event(event, people)
      end

      it "returns the created calendar event" do
        result = service.push_event(event, people)
        expect(result.id).to eq("google-event-123")
      end
    end

    context "when the credential is expired" do
      before { credential.update!(expires_at: 1.hour.ago) }

      it "refreshes the token" do
        expect(auth_double).to receive(:refresh!)
        service.push_event(event, people)
      end

      it "updates the stored access_token after refresh" do
        service.push_event(event, people)
        expect(credential.reload.access_token).to eq("new-access-token")
      end
    end

    context "calendar event structure" do
      before { credential.update!(expires_at: 1.hour.from_now) }

      it "sets the summary to the event display title" do
        expect(calendar_service_double).to receive(:insert_event) do |_calendar, cal_event|
          expect(cal_event.summary).to eq("Coffee chat")
          double("gcal_event")
        end
        service.push_event(event, people)
      end

      it "includes attendees from the people list" do
        expect(calendar_service_double).to receive(:insert_event) do |_calendar, cal_event|
          emails = cal_event.attendees.map(&:email)
          expect(emails).to include("alice@example.com")
          double("gcal_event")
        end
        service.push_event(event, people)
      end

      it "uses the person's timezone for the event time" do
        expect(calendar_service_double).to receive(:insert_event) do |_calendar, cal_event|
          expect(cal_event.start.time_zone).to eq("America/New_York")
          double("gcal_event")
        end
        service.push_event(event, people)
      end
    end

    context "when called with an empty people list" do
      it "falls back to UTC timezone" do
        expect(calendar_service_double).to receive(:insert_event) do |_calendar, cal_event|
          expect(cal_event.start.time_zone).to eq("UTC")
          double("gcal_event")
        end
        service.push_event(event, [])
      end
    end
  end

  private

  def stub_env_vars
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_ID").and_return("test-client-id")
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_SECRET").and_return("test-client-secret")
    allow(ENV).to receive(:fetch).with("GOOGLE_REDIRECT_URI").and_return("http://localhost:3000/auth/google/callback")
  end
end
