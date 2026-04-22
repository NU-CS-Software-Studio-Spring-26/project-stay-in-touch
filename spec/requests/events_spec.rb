require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:person_a) { create(:person) }
  let(:person_b) { create(:person) }

  let(:valid_attrs) do
    {
      occurred_at: 1.day.ago,
      medium: "coffee",
      title: "Morning check-in",
      notes: "Nice time",
      person_ids: [person_a.id, person_b.id]
    }
  end

  describe "GET /events" do
    it "renders the index" do
      create(:event, people: [person_a])
      get events_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Events")
    end
  end

  describe "GET /events/:id" do
    it "renders the show page" do
      event = create(:event, title: "Birthday", people: [person_a])
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
  end

  describe "PATCH /events/:id" do
    it "updates attributes and participants" do
      event = create(:event, title: "Old", people: [person_a])
      person_c = create(:person)

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
      event = create(:event, people: [person_a, person_b])
      expect {
        delete event_path(event)
      }.to change(Event, :count).by(-1)
        .and change(EventParticipant, :count).by(-2)
      expect(response).to redirect_to(events_path)
    end
  end
end
