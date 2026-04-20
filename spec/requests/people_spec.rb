require "rails_helper"

RSpec.describe "People", type: :request do
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

  describe "GET /people" do
    it "renders the index" do
      create_list(:person, 3)
      get people_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("People")
    end
  end

  describe "GET /people/:id" do
    it "renders the show page" do
      person = create(:person)
      get person_path(person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.name)
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
      person = create(:person)
      get edit_person_path(person)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /people/:id" do
    it "updates with valid params" do
      person = create(:person, name: "Old Name")
      patch person_path(person), params: { person: { name: "New Name" } }
      expect(response).to redirect_to(person_path(person))
      expect(person.reload.name).to eq("New Name")
    end

    it "re-renders edit with invalid params" do
      person = create(:person)
      patch person_path(person), params: { person: { email: "bad" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /people/:id" do
    it "destroys the person" do
      person = create(:person)
      expect {
        delete person_path(person)
      }.to change(Person, :count).by(-1)
      expect(response).to redirect_to(people_path)
    end
  end
end
