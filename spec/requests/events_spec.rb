require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:user)     { create(:user) }
  let(:person_a) { create(:person, user: user) }
  let(:person_b) { create(:person, user: user) }

  let(:valid_attrs) do
    {
      occurred_at: 1.day.ago,
      medium: "coffee",
      title: "Morning check-in",
      notes: "Nice time",
      person_ids: [person_a.id, person_b.id]
    }
  end

  before { sign_in(user) }

  describe "GET /events" do
    it "renders the index" do
      create(:event, people: [person_a], user: user)
      get events_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Events")
    end
  end

  describe "GET /events/:id" do
    it "renders the show page" do
      event = create(:event, title: "Birthday", people: [person_a], user: user)
      get event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Birthday")
    end
  end

  describe "POST /events" do
    it "creates an event with multiple participants" do
      expect {
        post events_path, params: { event: valid_attrs }
      }.to change(Event, :count).by(1)
      event = Event.last
      expect(event.user).to eq(user)
      expect(event.people).to contain_exactly(person_a, person_b)
      expect(response).to redirect_to(event_path(event))
    end

    it "fails when no participants are selected" do
      expect {
        post events_path, params: { event: valid_attrs.merge(person_ids: []) }
      }.not_to change(Event, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "succeeds when occurred_at is in the future" do
      expect {
        post events_path, params: { event: valid_attrs.merge(occurred_at: 1.day.from_now) }
      }.to change(Event, :count).by(1)
      expect(response).to redirect_to(event_path(Event.last))
    end

    it "ignores person_ids belonging to another user" do
      other_person = create(:person)
      expect {
        post events_path, params: { event: valid_attrs.merge(person_ids: [other_person.id]) }
      }.not_to change(Event, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /events validation feedback (#190)" do
    it "re-renders the form with a visible error when medium is missing" do
      post events_path, params: { event: valid_attrs.merge(medium: "") }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("prevented this event from being saved")
    end

    it "re-renders with a visible error when no participants are selected" do
      post events_path, params: { event: valid_attrs.merge(person_ids: []) }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("prevented this event from being saved")
    end
  end

  describe "POST /events quick-log failure surfaces in the modal (R1, #190)" do
    it "responds with a Turbo Stream that re-renders the modal and its error" do
      post events_path, params: {
        event: { occurred_at: 1.day.ago, person_ids: [person_a.id] }, # no medium
        quick_log: "1"
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("quick-log-modal")
      expect(response.body).to include("prevented this event from being saved")
    end
  end

  describe "timezone-aware event times (#188/#189/#96)" do
    before { user.update!(timezone: "America/Chicago") }

    it "stores a naive quick-log time as an instant in the user's zone" do
      post events_path, params: {
        event: { medium: "call", occurred_at: "2026-06-05T09:07", person_ids: [person_a.id] },
        quick_log: "1"
      }
      # 09:07 America/Chicago (CDT, UTC-5) == 14:07 UTC
      expect(Event.last.occurred_at).to eq(Time.utc(2026, 6, 5, 14, 7))
    end

    it "renders the stored instant back in the user's zone on the show page" do
      event = create(:event, user: user, people: [person_a],
                             occurred_at: Time.utc(2026, 6, 5, 14, 7))
      get event_path(event)
      expect(response.body).to include("09:07")
    end

    it "defaults the quick-log time to the top of the hour (no stray minutes, #188)" do
      get new_event_path(person_id: person_a.id), headers: { "Turbo-Frame" => "quick-log-modal" }
      expect(response.body).to match(/value="\d{4}-\d{2}-\d{2}T\d{2}:00"/)
    end
  end

  describe "POST /events scheduling against both calendars (#90)" do
    let(:invitee) { create(:user, email: "inv@example.com") }
    let(:invited_person) { create(:person, user: user, email: "inv@example.com") }

    it "consults a registered, Google-connected invitee's calendar" do
      create(:google_credential, user: invitee) # organizer is NOT connected here
      fake = instance_double(GoogleCalendarService, busy_intervals: [])
      expect(GoogleCalendarService).to receive(:new).with(invitee).and_return(fake)

      post events_path, params: { event: valid_attrs.merge(person_ids: [invited_person.id]) }

      expect(fake).to have_received(:busy_intervals)
    end

    it "consults both the organizer's and the invitee's calendars when both are connected" do
      create(:google_credential, user: user)
      create(:google_credential, user: invitee)
      organizer_service = instance_double(GoogleCalendarService, busy_intervals: [], push_event: nil)
      invitee_service   = instance_double(GoogleCalendarService, busy_intervals: [])
      allow(GoogleCalendarService).to receive(:new).with(user).and_return(organizer_service)
      allow(GoogleCalendarService).to receive(:new).with(invitee).and_return(invitee_service)

      post events_path, params: { event: valid_attrs.merge(person_ids: [invited_person.id]) }

      expect(organizer_service).to have_received(:busy_intervals)
      expect(invitee_service).to have_received(:busy_intervals)
    end

    it "does not consult an invited contact who is not a registered user" do
      stranger = create(:person, user: user, email: "stranger@example.com")
      expect(GoogleCalendarService).not_to receive(:new)

      post events_path, params: { event: valid_attrs.merge(person_ids: [stranger.id]) }

      expect(response).to redirect_to(event_path(Event.last))
    end
  end

  describe "PATCH /events/:id" do
    it "updates attributes and participants" do
      event   = create(:event, title: "Old", people: [person_a], user: user)
      person_c = create(:person, user: user)

      patch event_path(event), params: {
        event: { title: "New", person_ids: [person_a.id, person_c.id] }
      }

      expect(response).to redirect_to(event_path(event))
      event.reload
      expect(event.title).to eq("New")
      expect(event.people).to contain_exactly(person_a, person_c)
    end
  end

  describe "DELETE /events/:id" do
    it "destroys the event and its join rows" do
      event = create(:event, people: [person_a, person_b], user: user)
      expect {
        delete event_path(event)
      }.to change(Event, :count).by(-1)
        .and change(EventParticipant, :count).by(-2)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "cross-user isolation" do
    it "cannot view another user's event" do
      other_event = create(:event)
      get event_path(other_event)
      expect(response).to redirect_to(root_path)
    end

    it "cannot update another user's event" do
      other_event = create(:event)
      patch event_path(other_event), params: { event: { title: "Hacked" } }
      expect(response).to redirect_to(root_path)
    end

    it "cannot delete another user's event" do
      other_event = create(:event)
      expect {
        delete event_path(other_event)
      }.not_to change(Event, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /events with Serendipity-scheduled meetings" do
    let(:match_user)   { create(:user, display_name: "Dana Match") }
    let(:meeting_time) { Date.current.beginning_of_month.to_time + 9.days + 14.hours }

    def serendipity_proposal(**overrides)
      create(:meeting_proposal,
             { requester:           user,
               recipient:           match_user,
               status:              :accepted,
               calendar_created:    true,
               meeting_at:          meeting_time,
               calendar_event_link: "https://calendar.google.com/event?eid=abc123" }.merge(overrides))
    end

    it "links to the Google Calendar event Serendipity booked" do
      serendipity_proposal
      get events_path(month: meeting_time.strftime("%Y-%m"))

      expect(response.body).to include("Scheduled by Serendipity")
      expect(response.body).to include("Dana Match")
      expect(response.body).to include("https://calendar.google.com/event?eid=abc123")
    end

    it "shows meetings the user receives, not just ones they requested" do
      serendipity_proposal(requester: match_user, recipient: user)
      get events_path(month: meeting_time.strftime("%Y-%m"))

      expect(response.body).to include("Scheduled by Serendipity")
      expect(response.body).to include("Dana Match")
    end

    it "falls back to the match page when no calendar link was stored" do
      proposal = serendipity_proposal(calendar_event_link: nil)
      get events_path(month: meeting_time.strftime("%Y-%m"))

      expect(response.body).to include("Scheduled by Serendipity")
      expect(response.body).to include(match_path(proposal))
    end

    it "ignores declined and record-only proposals" do
      serendipity_proposal(status: :declined)
      serendipity_proposal(calendar_created: false, calendar_event_link: nil)
      get events_path(month: meeting_time.strftime("%Y-%m"))

      expect(response.body).not_to include("Scheduled by Serendipity")
    end

    it "omits the callout when the user has no scheduled matches" do
      get events_path(month: meeting_time.strftime("%Y-%m"))
      expect(response.body).not_to include("Scheduled by Serendipity")
    end
  end

  describe "GET /events/:id Google Calendar link" do
    it "links to the calendar event when one is stored" do
      event = create(:event, user: user, people: [person_a],
                             calendar_event_link: "https://calendar.google.com/event?eid=abc")
      get event_path(event)

      expect(response.body).to include("Open in Google Calendar")
      expect(response.body).to include("https://calendar.google.com/event?eid=abc")
    end

    it "offers to add to Google Calendar when connected but not yet synced" do
      create(:google_credential, user: user)
      event = create(:event, user: user, people: [person_a])
      get event_path(event)

      expect(response.body).to include("Add to Google Calendar")
    end

    it "shows no calendar action when not connected and not synced" do
      event = create(:event, user: user, people: [person_a])
      get event_path(event)

      expect(response.body).not_to include("Open in Google Calendar")
      expect(response.body).not_to include("Add to Google Calendar")
    end
  end

  describe "POST /events/:id/sync_calendar" do
    let(:event) { create(:event, user: user, people: [person_a]) }

    it "pushes to Google Calendar and stores the event link" do
      create(:google_credential, user: user)
      gcal_event   = double("GoogleEvent", id: "evt_1",
                            html_link: "https://calendar.google.com/event?eid=xyz")
      gcal_service = instance_double(GoogleCalendarService, push_event: gcal_event)
      allow(GoogleCalendarService).to receive(:new).with(user).and_return(gcal_service)

      post sync_calendar_event_path(event)

      expect(event.reload.calendar_event_link).to eq("https://calendar.google.com/event?eid=xyz")
      expect(event.calendar_event_id).to eq("evt_1")
      expect(response).to redirect_to(event_path(event))
    end

    it "redirects with an alert when Google Calendar is not connected" do
      post sync_calendar_event_path(event)

      expect(event.reload.calendar_event_link).to be_nil
      follow_redirect!
      expect(response.body).to include("Connect Google Calendar")
    end
  end

  describe "POST /events stores the calendar link" do
    it "stamps the Google Calendar link on the created event" do
      create(:google_credential, user: user)
      gcal_event   = double("GoogleEvent", id: "evt_9",
                            html_link: "https://calendar.google.com/event?eid=created")
      gcal_service = instance_double(GoogleCalendarService, busy_intervals: [], push_event: gcal_event)
      allow(GoogleCalendarService).to receive(:new).with(user).and_return(gcal_service)

      post events_path, params: { event: valid_attrs }

      expect(Event.last.calendar_event_link).to eq("https://calendar.google.com/event?eid=created")
    end
  end

  describe "unauthenticated access" do
    before { delete logout_path }

    it "redirects GET /events to login" do
      get events_path
      expect(response).to redirect_to(login_path)
    end

    it "redirects POST /events to login" do
      post events_path, params: { event: valid_attrs }
      expect(response).to redirect_to(login_path)
    end
  end
end
