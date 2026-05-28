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

  describe "#push_user_meeting" do
    let(:calendar_service_double) { instance_double(Google::Apis::CalendarV3::CalendarService) }
    let(:auth_double)             { instance_double(Signet::OAuth2::Client) }

    before do
      credential.update!(expires_at: 1.hour.from_now)
      allow(Signet::OAuth2::Client).to receive(:new).and_return(auth_double)
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(calendar_service_double)
      allow(calendar_service_double).to receive(:authorization=)
      allow(calendar_service_double).to receive(:insert_event)
        .and_return(double("gcal_event", id: "user-meeting-1"))
    end

    it "inserts the event on the primary calendar and returns it" do
      expect(calendar_service_double).to receive(:insert_event).with("primary", anything)
        .and_return(double("gcal_event", id: "user-meeting-1"))
      result = service.push_user_meeting(
        summary: "Intro", start_time: Time.utc(2026, 6, 1, 15, 0),
        attendee_emails: ["guest@example.com"]
      )
      expect(result.id).to eq("user-meeting-1")
    end

    it "adds the given attendee emails" do
      expect(calendar_service_double).to receive(:insert_event) do |_calendar, cal_event|
        expect(cal_event.attendees.map(&:email)).to eq(["guest@example.com"])
        double("gcal_event")
      end
      service.push_user_meeting(
        summary: "Intro", start_time: Time.utc(2026, 6, 1, 15, 0),
        attendee_emails: ["guest@example.com"]
      )
    end

    it "builds start and end times duration_minutes apart in the given timezone" do
      expect(calendar_service_double).to receive(:insert_event) do |_calendar, cal_event|
        expect(cal_event.start.time_zone).to eq("America/New_York")
        start_t = Time.parse(cal_event.start.date_time)
        end_t   = Time.parse(cal_event.end.date_time)
        expect((end_t - start_t) / 60).to eq(30)
        double("gcal_event")
      end
      service.push_user_meeting(
        summary: "Intro", start_time: Time.utc(2026, 6, 1, 15, 0),
        duration_minutes: 30, tz_name: "America/New_York", attendee_emails: []
      )
    end
  end

  describe ".earliest_free_slot" do
    let(:tz)  { ActiveSupport::TimeZone["UTC"] }
    let(:now) { tz.local(2026, 5, 1, 8, 0, 0) } # Fri 08:00 UTC

    it "returns the first slot inside preferred hours when nothing is busy" do
      slot = described_class.earliest_free_slot(
        busy: [], window_days: 1, from_hour: 9, to_hour: 17, now: now, tz: tz
      )
      expect(slot).to eq(tz.local(2026, 5, 1, 9, 0, 0))
    end

    it "skips a busy block, respecting the 15-minute buffer" do
      busy = [[tz.local(2026, 5, 1, 9, 0, 0), tz.local(2026, 5, 1, 10, 0, 0)]]
      slot = described_class.earliest_free_slot(
        busy: busy, window_days: 1, from_hour: 9, to_hour: 17, now: now, tz: tz
      )
      expect(slot).to eq(tz.local(2026, 5, 1, 10, 15, 0))
    end

    it "returns nil when every preferred-hour slot is busy" do
      busy = [[tz.local(2026, 5, 1, 0, 0, 0), tz.local(2026, 5, 2, 0, 0, 0)]]
      slot = described_class.earliest_free_slot(
        busy: busy, window_days: 1, from_hour: 9, to_hour: 10, now: now, tz: tz
      )
      expect(slot).to be_nil
    end
  end

  describe "#busy_intervals" do
    let(:calendar_service_double) { instance_double(Google::Apis::CalendarV3::CalendarService) }
    let(:auth_double)             { instance_double(Signet::OAuth2::Client) }
    let(:t1) { Time.utc(2026, 5, 1, 14, 0, 0) }
    let(:t2) { Time.utc(2026, 5, 1, 15, 0, 0) }

    before do
      allow(Signet::OAuth2::Client).to receive(:new).and_return(auth_double)
      allow(auth_double).to receive(:refresh!)
      allow(auth_double).to receive(:access_token).and_return("new-access-token")
      allow(auth_double).to receive(:expires_at).and_return(1.hour.from_now.to_i)
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(calendar_service_double)
      allow(calendar_service_double).to receive(:authorization=)
      credential.update!(expires_at: 1.hour.from_now)
    end

    it "returns busy [start, end] pairs from the primary calendar" do
      cal      = double("calendar", errors: [], busy: [double(start: t1, end: t2)])
      response = double("freebusy", calendars: { "primary" => cal })
      allow(calendar_service_double).to receive(:query_freebusy).and_return(response)

      expect(service.busy_intervals(window_days: 7)).to eq([[t1, t2]])
    end

    it "returns [] when the free/busy query raises" do
      allow(calendar_service_double).to receive(:query_freebusy).and_raise(StandardError)
      expect(service.busy_intervals(window_days: 7)).to eq([])
    end
  end

  private

  def stub_env_vars
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_ID").and_return("test-client-id")
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_SECRET").and_return("test-client-secret")
    allow(ENV).to receive(:fetch).with("GOOGLE_REDIRECT_URI").and_return("http://localhost:3000/auth/google/callback")
  end
end
