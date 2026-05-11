require "rails_helper"

RSpec.describe "People", type: :request do
  let(:user) { create(:user) }

  let(:valid_attrs) do
    {
      name: "Alice Tester",
      email: "alice.tester@example.com",
      timezone: "America/Chicago",
      preferred_start_hour: 9,
      preferred_end_hour: 21,
      frequency_weeks: 4.0,
      notes: "met at conference"
    }
  end

  let(:invalid_attrs) do
    valid_attrs.merge(email: "nope", name: "")
  end

  before { sign_in(user) }

  describe "GET /people" do
    it "renders the index" do
      create_list(:person, 3, user: user)
      get people_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("People")
    end

    it "does not show other users' people" do
      other_person = create(:person)
      get people_path
      expect(response.body).not_to include(other_person.name)
    end
  end

  describe "GET /people/:id" do
    it "renders the show page" do
      person = create(:person, user: user)
      get person_path(person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.name)
    end

    it "redirects for another user's person" do
      other_person = create(:person)
      get person_path(other_person)
      expect(response).to redirect_to(root_path)
    end

    context "AI reconnect message card" do
      let(:person) { create(:person, user: user) }

      context "when OPENROUTER_API_KEY is set and the service returns a message" do
        before do
          stub_const("ENV", ENV.to_h.merge("OPENROUTER_API_KEY" => "sk-test"))
          allow_any_instance_of(ReconnectMessageService).to receive(:call).and_return("Hey, let's catch up!")
        end

        it "shows the AI message card" do
          get person_path(person)
          expect(response.body).to include("Hey, let&#39;s catch up!")
          expect(response.body).to include("AI-suggested message")
        end
      end

      context "when OPENROUTER_API_KEY is not set" do
        before do
          stub_const("ENV", ENV.to_h.except("OPENROUTER_API_KEY"))
        end

        it "omits the AI message card without error" do
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("AI-suggested message")
        end
      end

      context "when OPENROUTER_API_KEY is set but the service returns nil (API error)" do
        before do
          stub_const("ENV", ENV.to_h.merge("OPENROUTER_API_KEY" => "sk-test"))
          allow_any_instance_of(ReconnectMessageService).to receive(:call).and_return(nil)
        end

        it "omits the AI message card without error" do
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("AI-suggested message")
        end
      end
    end
  end

  describe "GET /people/new" do
    it "renders the form" do
      get new_person_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /people" do
    it "creates a person with valid params" do
      expect {
        post people_path, params: { person: valid_attrs }
      }.to change(Person, :count).by(1)
      expect(Person.last.user).to eq(user)
      expect(response).to redirect_to(person_path(Person.last))
    end

    it "re-renders new with invalid params" do
      expect {
        post people_path, params: { person: invalid_attrs }
      }.not_to change(Person, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /people/:id/edit" do
    it "renders the edit form" do
      person = create(:person, user: user)
      get edit_person_path(person)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /people/:id" do
    it "updates with valid params" do
      person = create(:person, user: user, name: "Old Name")
      patch person_path(person), params: { person: { name: "New Name" } }
      expect(response).to redirect_to(person_path(person))
      expect(person.reload.name).to eq("New Name")
    end

    it "re-renders edit with invalid params" do
      person = create(:person, user: user)
      patch person_path(person), params: { person: { email: "bad" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /people/:id" do
    it "destroys the person" do
      person = create(:person, user: user)
      expect {
        delete person_path(person)
      }.to change(Person, :count).by(-1)
      expect(response).to redirect_to(people_path)
    end
  end

  describe "unauthenticated access" do
    before { delete logout_path }

    it "redirects GET /people to login" do
      get people_path
      expect(response).to redirect_to(login_path)
    end

    it "redirects POST /people to login" do
      post people_path, params: { person: valid_attrs }
      expect(response).to redirect_to(login_path)
    end
  end
end
